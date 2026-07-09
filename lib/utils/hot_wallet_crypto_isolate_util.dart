import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/utils/logger.dart';

class HotWalletUnlockParams {
  /// 사용자 입력 PIN. [deviceKeyOverride]가 있으면 빈 문자열.
  final String secret;
  final String encryptedSeedJson;
  final String wrappedDeviceKeyJson;

  /// base64 인코딩된 pepper. [deviceKeyOverride]가 있으면 빈 문자열이어도 무방.
  final String pepperBase64;
  final NetworkType networkType;

  /// 생체 빠른 경로에서 이미 확보한 DEK. 있으면 Argon2id 유도를 건너뛴다.
  final List<int>? deviceKeyOverride;

  const HotWalletUnlockParams({
    required this.secret,
    required this.encryptedSeedJson,
    required this.wrappedDeviceKeyJson,
    required this.pepperBase64,
    required this.networkType,
    this.deviceKeyOverride,
  });
}

class HotWalletSignPsbtParams extends HotWalletUnlockParams {
  final String unsignedPsbtBase64;

  /// 사용자가 입력한 BIP39 패스프레이즈(미저장). 패스프레이즈 미사용 지갑은 빈 문자열.
  final String passphrase;

  /// 패스프레이즈 지갑일 때 파생 볼트 descriptor 검증용.
  final String? expectedDescriptor;

  const HotWalletSignPsbtParams({
    required super.secret,
    required super.encryptedSeedJson,
    required super.wrappedDeviceKeyJson,
    required super.pepperBase64,
    required super.networkType,
    required this.unsignedPsbtBase64,
    this.passphrase = '',
    this.expectedDescriptor,
    super.deviceKeyOverride,
  });
}

class HotWalletVaultFromPayloadParams {
  final String mnemonic;
  final String passphrase;
  final NetworkType networkType;

  const HotWalletVaultFromPayloadParams({required this.mnemonic, required this.passphrase, required this.networkType});
}

Future<HotWalletSeedPayload> unlockSeedOffMainIsolate(HotWalletUnlockParams params) {
  return Isolate.run(() => _unlockSeedWorker(params));
}

Future<String> signPsbtOffMainIsolate(HotWalletSignPsbtParams params) {
  return Isolate.run(() => _signPsbtWorker(params));
}

Future<SingleSignatureVault> vaultFromPayloadOffMainIsolate(HotWalletVaultFromPayloadParams params) {
  return compute(_vaultFromPayloadWorker, params);
}

Future<List<int>> _resolveDeviceKey(HotWalletUnlockParams params) async {
  if (params.deviceKeyOverride != null) {
    Logger.performance('HotWalletSign: unwrapDeviceKey=0ms (deviceKeyOverride)');
    return params.deviceKeyOverride!;
  }

  final unwrapStart = DateTime.now();
  final deviceKey = await HotWalletEncryption.unwrapDeviceKey(
    wrapped: HotWalletWrappedDeviceKey.deserialize(params.wrappedDeviceKeyJson),
    secret: params.secret,
    pepper: base64Decode(params.pepperBase64),
  );
  Logger.performance('HotWalletSign: unwrapDeviceKey=${DateTime.now().difference(unwrapStart).inMilliseconds}ms');
  return deviceKey;
}

Future<HotWalletSeedPayload> _unlockSeedWorker(HotWalletUnlockParams params) async {
  final workerStart = DateTime.now();
  Logger.performance('HotWalletSign: isolate worker start (isolate=${Isolate.current.hashCode})');

  NetworkType.setNetworkType(params.networkType);

  final deviceKey = await _resolveDeviceKey(params);

  try {
    final decryptStart = DateTime.now();
    final encrypted = HotWalletEncryptedPayload.deserialize(params.encryptedSeedJson);
    final payload = await HotWalletEncryption.decryptSeed(encrypted, deviceKey);
    Logger.performance('HotWalletSign: decryptSeed=${DateTime.now().difference(decryptStart).inMilliseconds}ms');
    Logger.performance(
      'HotWalletSign: unlockSeed worker total=${DateTime.now().difference(workerStart).inMilliseconds}ms',
    );
    return payload;
  } finally {
    // 격리된 isolate 사본의 DEK를 사용 후 0으로 덮어쓴다. (main isolate 사본에는 영향 없음)
    zeroizeBytes(deviceKey);
  }
}

/// 민감한 바이트 버퍼를 0으로 덮어쓴다. 수정 불가한 리스트는 무시한다.
/// Dart String은 불변이라 완전 소거는 불가하며, 바이트 버퍼 위주로 정리한다.
void zeroizeBytes(List<int> bytes) {
  try {
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 0;
    }
  } catch (_) {
    // 고정/불변 리스트는 무시
  }
}

Future<String> _signPsbtWorker(HotWalletSignPsbtParams params) async {
  final workerStart = DateTime.now();
  Logger.performance('HotWalletSign: signPsbt worker start (isolate=${Isolate.current.hashCode})');

  final payload = await _unlockSeedWorker(params);

  final mnemonicBytes = Uint8List.fromList(utf8.encode(payload.mnemonic.trim()));
  final passphraseBytes =
      params.passphrase.isEmpty ? null : Uint8List.fromList(utf8.encode(params.passphrase));

  try {
    final vaultStart = DateTime.now();
    final vault = _buildVaultFromPayload(payload.mnemonic, params.passphrase, params.networkType);
    Logger.performance('HotWalletSign: fromMnemonic=${DateTime.now().difference(vaultStart).inMilliseconds}ms');

    if (params.expectedDescriptor != null && vault.descriptor != params.expectedDescriptor) {
      throw HotWalletPassphraseMismatchException();
    }

    final signStart = DateTime.now();
    final signedPsbt = vault.addSignatureToPsbt(params.unsignedPsbtBase64);
    Logger.performance('HotWalletSign: addSignatureToPsbt=${DateTime.now().difference(signStart).inMilliseconds}ms');
    Logger.performance('HotWalletSign: signPsbt worker total=${DateTime.now().difference(workerStart).inMilliseconds}ms');

    return signedPsbt;
  } finally {
    zeroizeBytes(mnemonicBytes);
    if (passphraseBytes != null) {
      zeroizeBytes(passphraseBytes);
    }
  }
}

SingleSignatureVault _vaultFromPayloadWorker(HotWalletVaultFromPayloadParams params) {
  return _buildVaultFromPayload(params.mnemonic, params.passphrase, params.networkType);
}

SingleSignatureVault _buildVaultFromPayload(String mnemonic, String passphrase, NetworkType networkType) {
  NetworkType.setNetworkType(networkType);
  final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic.trim()));
  final passphraseBytes = passphrase.isEmpty ? null : Uint8List.fromList(utf8.encode(passphrase));
  return SingleSignatureVault.fromMnemonic(mnemonicBytes, passphrase: passphraseBytes);
}
