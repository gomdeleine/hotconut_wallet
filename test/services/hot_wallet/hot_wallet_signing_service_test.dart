import 'package:hotconut_wallet/repository/secure_storage/hot_wallet_key_repository.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_signing_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryHotWalletKeyRepository extends HotWalletKeyRepository {
  final Map<int, String> _store = {};

  @override
  Future<void> saveEncryptedSeed(int walletId, String encryptedPayload) async {
    _store[walletId] = encryptedPayload;
  }

  @override
  Future<String?> readEncryptedSeed(int walletId) async => _store[walletId];

  @override
  Future<bool> hasEncryptedSeed(int walletId) async => _store.containsKey(walletId);
}

void main() {
  group('HotWalletSigningService', () {
    const pin = '4321';

    test('signPsbt fails for missing wallet seed', () async {
      final repository = _InMemoryHotWalletKeyRepository();
      final signingService = HotWalletSigningService(keyService: HotWalletKeyService(keyRepository: repository));

      expect(
        () => signingService.signPsbt(walletId: 99, unsignedPsbtBase64: 'cHNidP8=', secret: pin),
        throwsA(isA<HotWalletDecryptionException>()),
      );
    });

    test('verifySignedPsbt returns false for mismatched psbt', () async {
      final signingService = HotWalletSigningService();

      expect(await signingService.verifySignedPsbt('invalid', 'invalid'), isFalse);
    });
  });
}
