import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/repository/secure_storage/hot_wallet_key_repository.dart';
import 'package:hotconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:hotconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider hot wallet biometric fast path', () {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const pin = '123456';

    late SecureStorageRepository secureStorage;
    late HotWalletKeyRepository keyRepository;
    late HotWalletKeyService keyService;
    late AuthProvider authProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
      secureStorage = SecureStorageRepository.inMemory();
      keyRepository = HotWalletKeyRepository(secureStorage: secureStorage);
      keyService = HotWalletKeyService(keyRepository: keyRepository, kdfParamsOverride: HotWalletKdfParams.fast);
      authProvider = AuthProvider.test(secureStorage: secureStorage, hotWalletKeyService: keyService);
    });

    test('enableHotWalletBiometricFastPath stores device key when a hot wallet exists', () async {
      await keyService.saveSeed(walletId: 1, mnemonic: mnemonic, secret: pin, usesPassphrase: false);

      await authProvider.enableHotWalletBiometricFastPath(pin);

      expect(await keyService.readBiometricDeviceKey(), isNotNull);
    });

    test('enableHotWalletBiometricFastPath is a no-op without a hot wallet', () async {
      await authProvider.enableHotWalletBiometricFastPath(pin);

      expect(await keyService.readBiometricDeviceKey(), isNull);
    });

    test('saveIsSetBiometrics(false) removes stored biometric device key', () async {
      await keyService.saveSeed(walletId: 1, mnemonic: mnemonic, secret: pin, usesPassphrase: false);
      await authProvider.enableHotWalletBiometricFastPath(pin);
      expect(await keyService.readBiometricDeviceKey(), isNotNull);

      await authProvider.saveIsSetBiometrics(false);

      expect(await keyService.readBiometricDeviceKey(), isNull);
    });

    test('deletePin removes stored biometric device key', () async {
      await keyService.saveSeed(walletId: 1, mnemonic: mnemonic, secret: pin, usesPassphrase: false);
      await authProvider.enableHotWalletBiometricFastPath(pin);

      await authProvider.deletePin();

      expect(await keyService.readBiometricDeviceKey(), isNull);
    });
  });
}
