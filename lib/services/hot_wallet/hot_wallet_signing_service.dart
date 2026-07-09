import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:hotconut_wallet/utils/hot_wallet_crypto_isolate_util.dart';
import 'package:hotconut_wallet/utils/logger.dart';

class HotWalletSigningService {
  final HotWalletKeyService _keyService;

  HotWalletSigningService({HotWalletKeyService? keyService}) : _keyService = keyService ?? HotWalletKeyService();

  Future<HotWalletUnlockMaterials> loadUnlockMaterials(int walletId) => _keyService.loadUnlockMaterials(walletId);

  Future<bool> usesPassphrase(int walletId) => _keyService.usesPassphrase(walletId);

  Future<String> signPsbt({
    required int walletId,
    required String unsignedPsbtBase64,
    required String secret,
    String passphrase = '',
    String? expectedDescriptor,
    List<int>? deviceKeyOverride,
    HotWalletUnlockMaterials? preloadedMaterials,
  }) async {
    final totalStart = DateTime.now();
    final loadStart = DateTime.now();
    final signParams = await _keyService.buildSignParams(
      walletId: walletId,
      secret: secret,
      unsignedPsbtBase64: unsignedPsbtBase64,
      passphrase: passphrase,
      expectedDescriptor: expectedDescriptor,
      deviceKeyOverride: deviceKeyOverride,
      preloadedMaterials: preloadedMaterials,
    );
    if (preloadedMaterials == null) {
      Logger.performance('HotWalletSign: loadUnlockMaterials=${DateTime.now().difference(loadStart).inMilliseconds}ms');
    } else {
      Logger.performance('HotWalletSign: loadUnlockMaterials=0ms (preloaded)');
    }

    Logger.performance('HotWalletSign: signPsbtOffMainIsolate start (main isolate=${Isolate.current.hashCode})');
    final isolateStart = DateTime.now();
    final signedPsbt = await signPsbtOffMainIsolate(signParams);
    Logger.performance(
      'HotWalletSign: signPsbtOffMainIsolate=${DateTime.now().difference(isolateStart).inMilliseconds}ms',
    );
    Logger.performance('HotWalletSign: signPsbt total=${DateTime.now().difference(totalStart).inMilliseconds}ms');

    return signedPsbt;
  }

  Future<bool> verifySignedPsbt(String unsignedPsbtBase64, String signedPsbtBase64) async {
    try {
      final unsigned = Psbt.parse(unsignedPsbtBase64);
      final signed = Psbt.parse(signedPsbtBase64);
      return unsigned.sendingAmount == signed.sendingAmount &&
          unsigned.unsignedTransaction?.transactionHash == signed.unsignedTransaction?.transactionHash;
    } catch (_) {
      return false;
    }
  }
}
