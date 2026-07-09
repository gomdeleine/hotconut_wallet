import 'package:hotconut_wallet/constants/secure_keys.dart';
import 'package:hotconut_wallet/repository/secure_storage/secure_storage_repository.dart';

class HotWalletKeyRepository {
  final SecureStorageRepository _secureStorage;

  HotWalletKeyRepository({SecureStorageRepository? secureStorage})
    : _secureStorage = secureStorage ?? SecureStorageRepository();

  Future<void> saveEncryptedSeed(int walletId, String encryptedPayload) {
    return _secureStorage.write(key: SecureStorageKeys.hotWalletEncryptedSeedKey(walletId), value: encryptedPayload);
  }

  Future<String?> readEncryptedSeed(int walletId) {
    return _secureStorage.read(key: SecureStorageKeys.hotWalletEncryptedSeedKey(walletId));
  }

  Future<void> deleteEncryptedSeed(int walletId) {
    return _secureStorage.delete(key: SecureStorageKeys.hotWalletEncryptedSeedKey(walletId));
  }

  Future<bool> hasEncryptedSeed(int walletId) async {
    final value = await readEncryptedSeed(walletId);
    return value != null && value.isNotEmpty;
  }

  Future<List<int>> getHotWalletIds() async {
    final keys = await _secureStorage.getAllKeys();
    const prefix = SecureStorageKeys.kHotWalletEncryptedSeedPrefix;
    return keys
        .where((key) => key.startsWith(prefix))
        .map((key) => int.tryParse(key.substring(prefix.length)))
        .whereType<int>()
        .toList();
  }

  // --- wrapped device key (전역) ---

  Future<void> saveWrappedDeviceKey(String value) {
    return _secureStorage.write(key: SecureStorageKeys.kHotWalletWrappedDeviceKey, value: value);
  }

  Future<String?> readWrappedDeviceKey() {
    return _secureStorage.read(key: SecureStorageKeys.kHotWalletWrappedDeviceKey);
  }

  Future<void> deleteWrappedDeviceKey() {
    return _secureStorage.delete(key: SecureStorageKeys.kHotWalletWrappedDeviceKey);
  }

  // --- pepper (전역) ---

  Future<void> savePepper(String base64Pepper) {
    return _secureStorage.write(key: SecureStorageKeys.kHotWalletPepper, value: base64Pepper);
  }

  Future<String?> readPepper() {
    return _secureStorage.read(key: SecureStorageKeys.kHotWalletPepper);
  }

  Future<void> deletePepper() {
    return _secureStorage.delete(key: SecureStorageKeys.kHotWalletPepper);
  }

  // --- 지갑별 BIP39 패스프레이즈 사용 여부 ---

  Future<void> saveUsesPassphrase(int walletId, bool usesPassphrase) {
    return _secureStorage.write(
      key: SecureStorageKeys.hotWalletUsesPassphraseKey(walletId),
      value: usesPassphrase.toString(),
    );
  }

  Future<bool> readUsesPassphrase(int walletId) async {
    final value = await _secureStorage.read(key: SecureStorageKeys.hotWalletUsesPassphraseKey(walletId));
    return value == 'true';
  }

  Future<void> deleteUsesPassphrase(int walletId) {
    return _secureStorage.delete(key: SecureStorageKeys.hotWalletUsesPassphraseKey(walletId));
  }

  // --- biometric fast-path device key 사본 ---

  Future<void> saveBiometricDeviceKey(String base64DeviceKey) {
    return _secureStorage.write(key: SecureStorageKeys.kHotWalletBiometricDeviceKey, value: base64DeviceKey);
  }

  Future<String?> readBiometricDeviceKey() {
    return _secureStorage.read(key: SecureStorageKeys.kHotWalletBiometricDeviceKey);
  }

  Future<void> deleteBiometricDeviceKey() {
    return _secureStorage.delete(key: SecureStorageKeys.kHotWalletBiometricDeviceKey);
  }

  // --- 실패 횟수 (lockout/wipe) ---

  Future<void> saveFailedAttempts(int count) {
    return _secureStorage.write(key: SecureStorageKeys.kHotWalletFailedAttempts, value: count.toString());
  }

  Future<int> readFailedAttempts() async {
    final value = await _secureStorage.read(key: SecureStorageKeys.kHotWalletFailedAttempts);
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> deleteFailedAttempts() {
    return _secureStorage.delete(key: SecureStorageKeys.kHotWalletFailedAttempts);
  }
}
