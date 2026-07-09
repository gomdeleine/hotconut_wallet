const kSecureStoragePinKey = 'pin';

class SecureStorageKeys {
  static const String kSignedTransactionDraftPrefix = 'signed_transaction_draft_';
  static const String kHotWalletEncryptedSeedPrefix = 'hot_wallet_encrypted_seed_';
  static const String kHotWalletWrappedDeviceKey = 'hot_wallet_wrapped_device_key';

  /// 기기별 128bit 난수. PIN 단독 유출을 무력화하는 두 번째 요소.
  static const String kHotWalletPepper = 'hot_wallet_pepper';

  /// 지갑별 BIP39 패스프레이즈 사용 여부(값 자체는 저장하지 않음).
  static const String kHotWalletUsesPassphrasePrefix = 'hot_wallet_uses_passphrase_';

  /// 생체 빠른 경로용 DEK 사본. 생체인증 게이트 뒤에만 보관.
  static const String kHotWalletBiometricDeviceKey = 'hot_wallet_biometric_device_key';

  /// 연속 인증 실패 횟수(lockout/wipe 판단용).
  static const String kHotWalletFailedAttempts = 'hot_wallet_failed_attempts';

  static String hotWalletEncryptedSeedKey(int walletId) => '$kHotWalletEncryptedSeedPrefix$walletId';

  static String hotWalletUsesPassphraseKey(int walletId) => '$kHotWalletUsesPassphrasePrefix$walletId';
}
