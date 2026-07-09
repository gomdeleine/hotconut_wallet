import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/constants/secure_keys.dart';
import 'package:hotconut_wallet/repository/secure_storage/hot_wallet_key_repository.dart';
import 'package:hotconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HotWalletKeyService', () {
    late HotWalletKeyRepository repository;
    late SecureStorageRepository secureStorage;
    late HotWalletKeyService service;

    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const pin = '123456';
    const passphrase = 'test-passphrase';

    setUp(() {
      secureStorage = SecureStorageRepository.inMemory();
      repository = HotWalletKeyRepository(secureStorage: secureStorage);
      service = HotWalletKeyService(keyRepository: repository, kdfParamsOverride: HotWalletKdfParams.fast);
    });

    test('saveSeed and unlockVault descriptor match without passphrase', () async {
      final vault = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(mnemonic)));
      final expectedDescriptor = vault.descriptor;

      await service.saveSeed(walletId: 1, mnemonic: mnemonic, secret: pin, usesPassphrase: false);
      final unlocked = await service.unlockVault(walletId: 1, secret: pin, passphrase: '');

      expect(unlocked.descriptor, expectedDescriptor);
      expect(await secureStorage.read(key: SecureStorageKeys.kHotWalletWrappedDeviceKey), isNotNull);
      expect(await secureStorage.read(key: SecureStorageKeys.kHotWalletPepper), isNotNull);
      expect(await service.usesPassphrase(1), isFalse);
    });

    test('saveSeed stores usesPassphrase flag', () async {
      await service.saveSeed(walletId: 2, mnemonic: mnemonic, secret: pin, usesPassphrase: true);
      expect(await service.usesPassphrase(2), isTrue);
      expect(
        await secureStorage.read(key: SecureStorageKeys.hotWalletUsesPassphraseKey(2)),
        'true',
      );
    });

    test('unlockVault with passphrase derives correct descriptor', () async {
      final vault = SingleSignatureVault.fromMnemonic(
        Uint8List.fromList(utf8.encode(mnemonic)),
        passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      );
      await service.saveSeed(walletId: 3, mnemonic: mnemonic, secret: pin, usesPassphrase: true);

      final unlocked = await service.unlockVault(
        walletId: 3,
        secret: pin,
        passphrase: passphrase,
        expectedDescriptor: vault.descriptor,
      );
      expect(unlocked.descriptor, vault.descriptor);
    });

    test('unlockVault rejects wrong passphrase via descriptor check', () async {
      final vault = SingleSignatureVault.fromMnemonic(
        Uint8List.fromList(utf8.encode(mnemonic)),
        passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      );
      await service.saveSeed(walletId: 4, mnemonic: mnemonic, secret: pin, usesPassphrase: true);

      expect(
        () => service.unlockVault(
          walletId: 4,
          secret: pin,
          passphrase: 'wrong',
          expectedDescriptor: vault.descriptor,
        ),
        throwsA(isA<HotWalletPassphraseMismatchException>()),
      );
    });

    test('deleteSeed removes stored seed and flag', () async {
      await service.saveSeed(walletId: 5, mnemonic: mnemonic, secret: pin, usesPassphrase: true);
      await service.deleteSeed(5);

      expect(await repository.hasEncryptedSeed(5), isFalse);
      expect(await service.usesPassphrase(5), isFalse);
      expect(
        () => service.unlockVault(walletId: 5, secret: pin, passphrase: ''),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('device key is reused across wallets', () async {
      await service.saveSeed(walletId: 6, mnemonic: mnemonic, secret: pin, usesPassphrase: false);
      await service.saveSeed(walletId: 7, mnemonic: mnemonic, secret: pin, usesPassphrase: false);

      final seed6 = await service.unlockSeed(6, secret: pin);
      final seed7 = await service.unlockSeed(7, secret: pin);
      expect(seed6.mnemonic, seed7.mnemonic);
    });

    test('wrong secret fails unlockVault', () async {
      await service.saveSeed(walletId: 8, mnemonic: mnemonic, secret: pin, usesPassphrase: false);

      expect(
        () => service.unlockVault(walletId: 8, secret: '999999', passphrase: ''),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('changeSecret allows unlock with new PIN', () async {
      await service.saveSeed(walletId: 9, mnemonic: mnemonic, secret: pin, usesPassphrase: false);
      await service.changeSecret(oldSecret: pin, newSecret: '567890');

      final payload = await service.unlockSeed(9, secret: '567890');
      expect(payload.mnemonic, mnemonic);
      expect(
        () => service.unlockVault(walletId: 9, secret: pin, passphrase: ''),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('biometric fast path stores and returns device key', () async {
      await service.saveSeed(walletId: 10, mnemonic: mnemonic, secret: pin, usesPassphrase: false);
      await service.enableBiometricFastPath(pin);

      final deviceKey = await service.readBiometricDeviceKey();
      expect(deviceKey, isNotNull);

      final payload = await service.unlockSeed(10, secret: '', deviceKeyOverride: deviceKey);
      expect(payload.mnemonic, mnemonic);

      await service.disableBiometricFastPath();
      expect(await service.readBiometricDeviceKey(), isNull);
    });

    test('failed attempts counter', () async {
      expect(await service.getFailedAttempts(), 0);
      expect(await service.recordFailedAttempt(), 1);
      expect(await service.recordFailedAttempt(), 2);
      await service.resetFailedAttempts();
      expect(await service.getFailedAttempts(), 0);
    });
  });
}
