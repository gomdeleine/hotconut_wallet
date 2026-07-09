import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HotWalletEncryption', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const secret = '123456';
    const fast = HotWalletKdfParams.fast;

    test('seed encrypt and decrypt roundtrip (v1)', () async {
      final payload = HotWalletSeedPayload(mnemonic: mnemonic);
      final deviceKey = HotWalletEncryption.generateDeviceKey();
      final encrypted = await HotWalletEncryption.encryptSeed(payload, deviceKey);
      final decrypted = await HotWalletEncryption.decryptSeed(encrypted, deviceKey);

      expect(decrypted.mnemonic, mnemonic);
      expect(encrypted.version, HotWalletEncryption.payloadVersion);
      expect(encrypted.version, 1);
    });

    test('device key is 128-bit', () {
      expect(HotWalletEncryption.generateDeviceKey().length, 16);
      expect(HotWalletEncryption.generatePepper().length, 16);
    });

    test('wrap and unwrap device key roundtrip', () async {
      final deviceKey = HotWalletEncryption.generateDeviceKey();
      final pepper = HotWalletEncryption.generatePepper();
      final wrapped = await HotWalletEncryption.wrapDeviceKey(
        deviceKey: deviceKey,
        secret: secret,
        pepper: pepper,
        kdfParams: fast,
      );
      final unwrapped = await HotWalletEncryption.unwrapDeviceKey(wrapped: wrapped, secret: secret, pepper: pepper);

      expect(unwrapped, deviceKey);
      expect(wrapped.kdfParams.memory, fast.memory);
    });

    test('wrong secret fails device key unwrap', () async {
      final deviceKey = HotWalletEncryption.generateDeviceKey();
      final pepper = HotWalletEncryption.generatePepper();
      final wrapped = await HotWalletEncryption.wrapDeviceKey(
        deviceKey: deviceKey,
        secret: secret,
        pepper: pepper,
        kdfParams: fast,
      );

      expect(
        () => HotWalletEncryption.unwrapDeviceKey(wrapped: wrapped, secret: '999999', pepper: pepper),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('wrong pepper fails device key unwrap (second factor)', () async {
      final deviceKey = HotWalletEncryption.generateDeviceKey();
      final pepper = HotWalletEncryption.generatePepper();
      final wrapped = await HotWalletEncryption.wrapDeviceKey(
        deviceKey: deviceKey,
        secret: secret,
        pepper: pepper,
        kdfParams: fast,
      );

      expect(
        () => HotWalletEncryption.unwrapDeviceKey(
          wrapped: wrapped,
          secret: secret,
          pepper: HotWalletEncryption.generatePepper(),
        ),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('different salts produce different wrapped ciphertext', () async {
      final deviceKey = HotWalletEncryption.generateDeviceKey();
      final pepper = HotWalletEncryption.generatePepper();
      final first = await HotWalletEncryption.wrapDeviceKey(
        deviceKey: deviceKey,
        secret: secret,
        pepper: pepper,
        kdfParams: fast,
      );
      final second = await HotWalletEncryption.wrapDeviceKey(
        deviceKey: deviceKey,
        secret: secret,
        pepper: pepper,
        kdfParams: fast,
      );

      expect(first.salt, isNot(equals(second.salt)));
      expect(first.ciphertext, isNot(equals(second.ciphertext)));
    });

    test('unsupported payload version throws', () {
      expect(
        () => HotWalletWrappedDeviceKey.deserialize('{"version":2,"kdf":{"memory":1,"iterations":1,"parallelism":1},"salt":"","nonce":"","ciphertext":"","mac":""}'),
        throwsA(isA<HotWalletUnsupportedVersionException>()),
      );
    });
  });
}
