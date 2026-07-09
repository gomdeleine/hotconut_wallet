import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// 복호화된 시드 자료. 사용 후 메모리에서 지운다.
class HotWalletSeedPayload {
  final String mnemonic;

  const HotWalletSeedPayload({required this.mnemonic});

  Map<String, dynamic> toJson() => {'mnemonic': mnemonic};

  factory HotWalletSeedPayload.fromJson(Map<String, dynamic> json) {
    return HotWalletSeedPayload(mnemonic: json['mnemonic'] as String);
  }
}

/// DEK로 암호화된 시드. (payload v1, AES-128-GCM)
class HotWalletEncryptedPayload {
  final int version;
  final String nonce;
  final String ciphertext;
  final String mac;

  const HotWalletEncryptedPayload({
    required this.version,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  Map<String, dynamic> toJson() => {'version': version, 'nonce': nonce, 'ciphertext': ciphertext, 'mac': mac};

  factory HotWalletEncryptedPayload.fromJson(Map<String, dynamic> json) {
    return HotWalletEncryptedPayload(
      version: json['version'] as int,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
      mac: json['mac'] as String,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory HotWalletEncryptedPayload.deserialize(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    if ((json['version'] as int?) != HotWalletEncryption.payloadVersion) {
      throw HotWalletUnsupportedVersionException();
    }
    return HotWalletEncryptedPayload.fromJson(json);
  }
}

/// Argon2id 비용 파라미터. wrapped DEK 안에 함께 저장되어 복호화 시 재사용된다.
class HotWalletKdfParams {
  /// 1kB 블록 수 (예: 19456 = 19 MiB)
  final int memory;
  final int iterations;
  final int parallelism;

  const HotWalletKdfParams({required this.memory, required this.iterations, required this.parallelism});

  static const HotWalletKdfParams standard = HotWalletKdfParams(memory: 19456, iterations: 2, parallelism: 1);

  /// 테스트 전용: brute force 방어가 필요 없는 단위 테스트에서 사용.
  @visibleForTesting
  static const HotWalletKdfParams fast = HotWalletKdfParams(memory: 256, iterations: 1, parallelism: 1);

  Map<String, dynamic> toJson() => {'memory': memory, 'iterations': iterations, 'parallelism': parallelism};

  factory HotWalletKdfParams.fromJson(Map<String, dynamic> json) {
    return HotWalletKdfParams(
      memory: json['memory'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
    );
  }
}

/// pepper + PIN에서 유도한 KEK로 래핑된 DEK. (payload v1)
class HotWalletWrappedDeviceKey {
  static const int version = 1;

  final HotWalletKdfParams kdfParams;
  final String salt;
  final String nonce;
  final String ciphertext;
  final String mac;

  const HotWalletWrappedDeviceKey({
    required this.kdfParams,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'kdf': kdfParams.toJson(),
    'salt': salt,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };

  factory HotWalletWrappedDeviceKey.fromJson(Map<String, dynamic> json) {
    return HotWalletWrappedDeviceKey(
      kdfParams: HotWalletKdfParams.fromJson(json['kdf'] as Map<String, dynamic>),
      salt: json['salt'] as String,
      nonce: json['nonce'] as String,
      ciphertext: json['ciphertext'] as String,
      mac: json['mac'] as String,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory HotWalletWrappedDeviceKey.deserialize(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    if ((json['version'] as int?) != version) {
      throw HotWalletUnsupportedVersionException();
    }
    return HotWalletWrappedDeviceKey.fromJson(json);
  }
}

class HotWalletDecryptionException implements Exception {
  final String message;

  HotWalletDecryptionException([this.message = 'Failed to decrypt hot wallet seed']);

  @override
  String toString() => message;
}

/// 패스프레이즈로 파생한 볼트가 저장된 지갑 descriptor와 일치하지 않을 때.
class HotWalletPassphraseMismatchException extends HotWalletDecryptionException {
  HotWalletPassphraseMismatchException() : super('BIP39 passphrase does not match this wallet');
}

/// 지원하지 않는 payload 버전 발견 시. 하위호환을 제공하지 않으므로 재설정이 필요하다.
class HotWalletUnsupportedVersionException extends HotWalletDecryptionException {
  HotWalletUnsupportedVersionException() : super('Unsupported hot wallet payload version. Re-setup required.');
}

/// 핫월렛 시드 봉투 암호화(envelope encryption).
///
/// - DEK(128bit 난수)로 시드를 AES-128-GCM 암호화한다.
/// - KEK = HKDF-SHA256( ikm: Argon2id(PIN, salt), salt: pepper ) 로 DEK를 AES-256-GCM 래핑한다.
/// - pepper(128bit 난수)는 secure storage의 별도 항목으로 저장되어 PIN 단독 유출을 무력화한다.
class HotWalletEncryption {
  static const int payloadVersion = 1;
  static const int _saltLength = 16;
  static const int _deviceKeyLength = 16; // 128-bit DEK
  static const int _pepperLength = 16; // 128-bit pepper
  static const int _kekLength = 32;
  static final List<int> _kekInfo = utf8.encode('hotconut-hot-wallet-kek-v1');

  static final AesGcm _dekCipher = AesGcm.with128bits();
  static final AesGcm _kekCipher = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: _kekLength);

  static Uint8List generateDeviceKey() => _randomBytes(_deviceKeyLength);

  static Uint8List generatePepper() => _randomBytes(_pepperLength);

  static Future<HotWalletEncryptedPayload> encryptSeed(HotWalletSeedPayload payload, List<int> deviceKey) async {
    if (deviceKey.length != _deviceKeyLength) {
      throw ArgumentError('Device key must be $_deviceKeyLength bytes');
    }

    final secretKey = SecretKey(deviceKey);
    final nonce = _dekCipher.newNonce();
    final secretBox = await _dekCipher.encrypt(
      utf8.encode(jsonEncode(payload.toJson())),
      secretKey: secretKey,
      nonce: nonce,
    );

    return HotWalletEncryptedPayload(
      version: payloadVersion,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(secretBox.cipherText),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

  static Future<HotWalletSeedPayload> decryptSeed(HotWalletEncryptedPayload encrypted, List<int> deviceKey) async {
    try {
      final secretBox = SecretBox(
        base64Decode(encrypted.ciphertext),
        nonce: base64Decode(encrypted.nonce),
        mac: Mac(base64Decode(encrypted.mac)),
      );
      final decryptedBytes = await _dekCipher.decrypt(secretBox, secretKey: SecretKey(deviceKey));
      final json = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
      return HotWalletSeedPayload.fromJson(json);
    } catch (_) {
      throw HotWalletDecryptionException();
    }
  }

  static Future<HotWalletWrappedDeviceKey> wrapDeviceKey({
    required List<int> deviceKey,
    required String secret,
    required List<int> pepper,
    HotWalletKdfParams? kdfParams,
  }) async {
    if (deviceKey.length != _deviceKeyLength) {
      throw ArgumentError('Device key must be $_deviceKeyLength bytes');
    }

    final params = kdfParams ?? HotWalletKdfParams.standard;
    final salt = _randomBytes(_saltLength);
    final kek = await _deriveKek(secret: secret, salt: salt, pepper: pepper, params: params);
    final nonce = _kekCipher.newNonce();
    final secretBox = await _kekCipher.encrypt(deviceKey, secretKey: kek, nonce: nonce);

    return HotWalletWrappedDeviceKey(
      kdfParams: params,
      salt: base64Encode(salt),
      nonce: base64Encode(nonce),
      ciphertext: base64Encode(secretBox.cipherText),
      mac: base64Encode(secretBox.mac.bytes),
    );
  }

  static Future<List<int>> unwrapDeviceKey({
    required HotWalletWrappedDeviceKey wrapped,
    required String secret,
    required List<int> pepper,
  }) async {
    try {
      final kek = await _deriveKek(
        secret: secret,
        salt: base64Decode(wrapped.salt),
        pepper: pepper,
        params: wrapped.kdfParams,
      );
      final secretBox = SecretBox(
        base64Decode(wrapped.ciphertext),
        nonce: base64Decode(wrapped.nonce),
        mac: Mac(base64Decode(wrapped.mac)),
      );
      final deviceKey = await _kekCipher.decrypt(secretBox, secretKey: kek);
      if (deviceKey.length != _deviceKeyLength) {
        throw HotWalletDecryptionException('Invalid device key length');
      }
      return deviceKey;
    } catch (e) {
      if (e is HotWalletDecryptionException) rethrow;
      throw HotWalletDecryptionException();
    }
  }

  static Future<SecretKey> _deriveKek({
    required String secret,
    required List<int> salt,
    required List<int> pepper,
    required HotWalletKdfParams params,
  }) async {
    final argon2 = Argon2id(
      memory: params.memory,
      parallelism: params.parallelism,
      iterations: params.iterations,
      hashLength: _kekLength,
    );
    final ikm = await argon2.deriveKey(secretKey: SecretKey(utf8.encode(secret)), nonce: salt);
    return _hkdf.deriveKey(secretKey: ikm, nonce: pepper, info: _kekInfo);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));
  }
}
