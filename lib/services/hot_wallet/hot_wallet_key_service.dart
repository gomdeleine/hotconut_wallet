import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:hotconut_wallet/repository/secure_storage/hot_wallet_key_repository.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/utils/hot_wallet_crypto_isolate_util.dart';

class HotWalletUnlockMaterials {
  final String encryptedSeedJson;
  final String wrappedDeviceKeyJson;
  final String pepperBase64;

  const HotWalletUnlockMaterials({
    required this.encryptedSeedJson,
    required this.wrappedDeviceKeyJson,
    required this.pepperBase64,
  });
}

class HotWalletKeyService {
  final HotWalletKeyRepository _keyRepository;
  final Future<List<int>> Function()? _deviceKeyLoader;
  final HotWalletKdfParams? _kdfParamsOverride;

  HotWalletKeyService({
    HotWalletKeyRepository? keyRepository,
    Future<List<int>> Function()? deviceKeyLoader,
    @visibleForTesting HotWalletKdfParams? kdfParamsOverride,
  }) : _keyRepository = keyRepository ?? HotWalletKeyRepository(),
       _deviceKeyLoader = deviceKeyLoader,
       _kdfParamsOverride = kdfParamsOverride;

  Future<bool> hasWrappedDeviceKey() async {
    final stored = await _keyRepository.readWrappedDeviceKey();
    return stored != null && stored.isNotEmpty;
  }

  Future<bool> usesPassphrase(int walletId) => _keyRepository.readUsesPassphrase(walletId);

  // --- 시드 저장/복호화 ---

  Future<void> saveSeed({
    required int walletId,
    required String mnemonic,
    required String secret,
    required bool usesPassphrase,
  }) async {
    final deviceKey = await _getOrCreateDeviceKey(secret: secret);
    final encrypted = await HotWalletEncryption.encryptSeed(
      HotWalletSeedPayload(mnemonic: mnemonic),
      deviceKey,
    );
    await _keyRepository.saveEncryptedSeed(walletId, encrypted.serialize());
    await _keyRepository.saveUsesPassphrase(walletId, usesPassphrase);
  }

  Future<HotWalletUnlockMaterials> loadUnlockMaterials(int walletId) async {
    final stored = await _keyRepository.readEncryptedSeed(walletId);
    if (stored == null) {
      throw HotWalletDecryptionException('Hot wallet seed not found');
    }

    final wrappedDeviceKey = await _keyRepository.readWrappedDeviceKey();
    if (wrappedDeviceKey == null) {
      throw HotWalletDecryptionException('Hot wallet device key not found');
    }

    final pepper = await _keyRepository.readPepper();
    if (pepper == null) {
      throw HotWalletDecryptionException('Hot wallet pepper not found');
    }

    return HotWalletUnlockMaterials(
      encryptedSeedJson: stored,
      wrappedDeviceKeyJson: wrappedDeviceKey,
      pepperBase64: pepper,
    );
  }

  Future<HotWalletUnlockParams> buildUnlockParams(
    int walletId, {
    required String secret,
    List<int>? deviceKeyOverride,
    HotWalletUnlockMaterials? preloadedMaterials,
  }) async {
    final materials = preloadedMaterials ?? await loadUnlockMaterials(walletId);
    return HotWalletUnlockParams(
      secret: secret,
      encryptedSeedJson: materials.encryptedSeedJson,
      wrappedDeviceKeyJson: materials.wrappedDeviceKeyJson,
      pepperBase64: materials.pepperBase64,
      networkType: NetworkType.currentNetworkType,
      deviceKeyOverride: deviceKeyOverride ?? (_deviceKeyLoader != null ? await _deviceKeyLoader() : null),
    );
  }

  Future<HotWalletSignPsbtParams> buildSignParams({
    required int walletId,
    required String secret,
    required String unsignedPsbtBase64,
    String passphrase = '',
    String? expectedDescriptor,
    List<int>? deviceKeyOverride,
    HotWalletUnlockMaterials? preloadedMaterials,
  }) async {
    final unlockParams = await buildUnlockParams(
      walletId,
      secret: secret,
      deviceKeyOverride: deviceKeyOverride,
      preloadedMaterials: preloadedMaterials,
    );
    return HotWalletSignPsbtParams(
      secret: unlockParams.secret,
      encryptedSeedJson: unlockParams.encryptedSeedJson,
      wrappedDeviceKeyJson: unlockParams.wrappedDeviceKeyJson,
      pepperBase64: unlockParams.pepperBase64,
      networkType: unlockParams.networkType,
      unsignedPsbtBase64: unsignedPsbtBase64,
      passphrase: passphrase,
      expectedDescriptor: expectedDescriptor,
      deviceKeyOverride: unlockParams.deviceKeyOverride,
    );
  }

  Future<HotWalletSeedPayload> unlockSeed(int walletId, {required String secret, List<int>? deviceKeyOverride}) async {
    final params = await buildUnlockParams(walletId, secret: secret, deviceKeyOverride: deviceKeyOverride);
    return unlockSeedOffMainIsolate(params);
  }

  Future<SingleSignatureVault> unlockVault({
    required int walletId,
    required String secret,
    required String passphrase,
    String? expectedDescriptor,
    List<int>? deviceKeyOverride,
  }) async {
    final payload = await unlockSeed(walletId, secret: secret, deviceKeyOverride: deviceKeyOverride);
    final vault = vaultFromPayload(payload.mnemonic, passphrase);
    if (expectedDescriptor != null && vault.descriptor != expectedDescriptor) {
      throw HotWalletPassphraseMismatchException();
    }
    return vault;
  }

  SingleSignatureVault vaultFromPayload(String mnemonic, String passphrase) {
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic.trim()));
    final passphraseBytes = passphrase.isEmpty ? null : Uint8List.fromList(utf8.encode(passphrase));
    return SingleSignatureVault.fromMnemonic(mnemonicBytes, passphrase: passphraseBytes);
  }

  Future<void> deleteSeed(int walletId) async {
    await _keyRepository.deleteEncryptedSeed(walletId);
    await _keyRepository.deleteUsesPassphrase(walletId);
  }

  Future<bool> hasSeed(int walletId) => _keyRepository.hasEncryptedSeed(walletId);

  // --- PIN 변경 (DEK 재래핑) ---

  Future<void> changeSecret({required String oldSecret, required String newSecret}) async {
    if (!await hasWrappedDeviceKey()) return;

    final storedWrap = await _keyRepository.readWrappedDeviceKey();
    if (storedWrap == null) return;

    final pepper = await _getOrCreatePepper();
    final deviceKey = await HotWalletEncryption.unwrapDeviceKey(
      wrapped: HotWalletWrappedDeviceKey.deserialize(storedWrap),
      secret: oldSecret,
      pepper: pepper,
    );
    await _saveWrappedDeviceKey(deviceKey: deviceKey, secret: newSecret, pepper: pepper);
  }

  // --- 생체 빠른 경로 ---

  Future<void> enableBiometricFastPath(String secret) async {
    if (!await hasWrappedDeviceKey()) return;
    final deviceKey = await _getOrCreateDeviceKey(secret: secret);
    await _keyRepository.saveBiometricDeviceKey(base64Encode(deviceKey));
  }

  Future<void> disableBiometricFastPath() => _keyRepository.deleteBiometricDeviceKey();

  Future<List<int>?> readBiometricDeviceKey() async {
    final value = await _keyRepository.readBiometricDeviceKey();
    if (value == null) return null;
    return base64Decode(value);
  }

  // --- 실패 횟수 (lockout / wipe) ---

  Future<int> getFailedAttempts() => _keyRepository.readFailedAttempts();

  Future<int> recordFailedAttempt() async {
    final next = (await _keyRepository.readFailedAttempts()) + 1;
    await _keyRepository.saveFailedAttempts(next);
    return next;
  }

  Future<void> resetFailedAttempts() => _keyRepository.deleteFailedAttempts();

  /// 모든 핫월렛 비밀 자료를 삭제한다. (지갑 목록/Realm 정리는 상위 계층 책임)
  Future<void> wipeAllHotWalletSecrets() async {
    final ids = await _keyRepository.getHotWalletIds();
    for (final id in ids) {
      await _keyRepository.deleteEncryptedSeed(id);
      await _keyRepository.deleteUsesPassphrase(id);
    }
    await _keyRepository.deleteWrappedDeviceKey();
    await _keyRepository.deletePepper();
    await _keyRepository.deleteBiometricDeviceKey();
    await _keyRepository.deleteFailedAttempts();
  }

  // --- 내부 ---

  Future<List<int>> _getOrCreateDeviceKey({required String secret}) async {
    if (_deviceKeyLoader != null) {
      return _deviceKeyLoader();
    }

    final pepper = await _getOrCreatePepper();
    final storedWrap = await _keyRepository.readWrappedDeviceKey();
    if (storedWrap != null) {
      return HotWalletEncryption.unwrapDeviceKey(
        wrapped: HotWalletWrappedDeviceKey.deserialize(storedWrap),
        secret: secret,
        pepper: pepper,
      );
    }

    final deviceKey = HotWalletEncryption.generateDeviceKey();
    await _saveWrappedDeviceKey(deviceKey: deviceKey, secret: secret, pepper: pepper);
    return deviceKey;
  }

  Future<List<int>> _getOrCreatePepper() async {
    final stored = await _keyRepository.readPepper();
    if (stored != null && stored.isNotEmpty) {
      return base64Decode(stored);
    }
    final pepper = HotWalletEncryption.generatePepper();
    await _keyRepository.savePepper(base64Encode(pepper));
    return pepper;
  }

  Future<void> _saveWrappedDeviceKey({
    required List<int> deviceKey,
    required String secret,
    required List<int> pepper,
  }) async {
    final wrapped = await HotWalletEncryption.wrapDeviceKey(
      deviceKey: deviceKey,
      secret: secret,
      pepper: pepper,
      kdfParams: _kdfParamsOverride,
    );
    await _keyRepository.saveWrappedDeviceKey(wrapped.serialize());
  }
}
