import 'dart:isolate';

import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/send_info_provider.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_signing_service.dart';
import 'package:hotconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 패스프레이즈 연속 실패가 이 횟수에 도달하면 시드 삭제를 안내한다.
const int kHotWalletPassphraseWipeThreshold = 10;

/// PIN/생체 준비 결과.
enum HotWalletSignPrepareOutcome { signed, needPassphrase, failed }

class HotWalletSignViewModel extends ChangeNotifier {
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;
  final HotWalletSigningService _signingService;
  final HotWalletKeyService _keyService;
  final AuthProvider _authProvider;

  bool _isSigning = false;
  String? _errorMessage;
  HotWalletUnlockMaterials? _preloadedMaterials;
  bool _usesPassphrase = false;
  int _failedAttempts = 0;

  String? _verifiedPin;
  List<int>? _deviceKeyOverride;

  HotWalletSignViewModel(
    this._sendInfoProvider,
    this._walletProvider,
    this._authProvider, {
    HotWalletSigningService? signingService,
    HotWalletKeyService? keyService,
  }) : _signingService = signingService ?? HotWalletSigningService(),
       _keyService = keyService ?? HotWalletKeyService();

  bool get isSigning => _isSigning;
  String? get errorMessage => _errorMessage;
  int get walletId => _sendInfoProvider.walletId!;
  String get walletName => _walletProvider.getWalletById(walletId).name;

  bool get usesPassphrase => _usesPassphrase;
  bool get isBiometricAvailable => _authProvider.isBiometricsAuthEnabled;
  int get failedAttempts => _failedAttempts;
  bool get shouldSuggestWipe => _usesPassphrase && _failedAttempts >= kHotWalletPassphraseWipeThreshold;

  String? get _expectedDescriptor {
    if (!_usesPassphrase) return null;
    return _walletProvider.getWalletById(walletId).descriptor;
  }

  Future<void> init() async {
    _usesPassphrase = await _keyService.usesPassphrase(walletId);
    _failedAttempts = await _keyService.getFailedAttempts();
    notifyListeners();
    await preloadUnlockMaterials();
  }

  Future<void> preloadUnlockMaterials() async {
    final start = DateTime.now();
    try {
      _preloadedMaterials = await _signingService.loadUnlockMaterials(walletId);
      Logger.performance(
        'HotWalletSign: preloadUnlockMaterials=${DateTime.now().difference(start).inMilliseconds}ms (main isolate=${Isolate.current.hashCode})',
      );
    } catch (e) {
      _preloadedMaterials = null;
      Logger.performance('HotWalletSign: preloadUnlockMaterials failed: $e');
    }
  }

  /// PIN 검증 후 패스프레이즈 미사용 지갑이면 즉시 서명, 사용 지갑이면 needPassphrase 반환.
  Future<HotWalletSignPrepareOutcome> verifyPinAndPrepare(String pin) async {
    final pinValid = await _authProvider.verifyPin(pin);
    if (!pinValid) {
      _errorMessage = 'pin_incorrect';
      notifyListeners();
      return HotWalletSignPrepareOutcome.failed;
    }

    _verifiedPin = pin;
    _deviceKeyOverride = null;

    if (_authProvider.isBiometricsAuthEnabled && await _keyService.readBiometricDeviceKey() == null) {
      await _keyService.enableBiometricFastPath(pin);
    }

    if (!_usesPassphrase) {
      final ok = await _sign(secret: pin);
      return ok ? HotWalletSignPrepareOutcome.signed : HotWalletSignPrepareOutcome.failed;
    }

    notifyListeners();
    return HotWalletSignPrepareOutcome.needPassphrase;
  }

  /// 생체인증 후 패스프레이즈 미사용 지갑이면 즉시 서명, 사용 지갑이면 needPassphrase 반환.
  Future<HotWalletSignPrepareOutcome> prepareWithBiometrics() async {
    final deviceKey = await _authProvider.unlockHotWalletDeviceKeyWithBiometrics();
    if (deviceKey == null) return HotWalletSignPrepareOutcome.failed;

    _verifiedPin = null;
    _deviceKeyOverride = deviceKey;

    if (!_usesPassphrase) {
      final ok = await _sign(secret: '', deviceKeyOverride: deviceKey);
      return ok ? HotWalletSignPrepareOutcome.signed : HotWalletSignPrepareOutcome.failed;
    }

    notifyListeners();
    return HotWalletSignPrepareOutcome.needPassphrase;
  }

  Future<bool> signWithPassphrase(String passphrase) async {
    final secret = _verifiedPin ?? '';
    final deviceKey = _deviceKeyOverride;
    return _sign(secret: secret, passphrase: passphrase, deviceKeyOverride: deviceKey);
  }

  void clearSensitiveState() {
    _verifiedPin = null;
    _deviceKeyOverride = null;
    notifyListeners();
  }

  Future<bool> _sign({required String secret, String passphrase = '', List<int>? deviceKeyOverride}) async {
    _isSigning = true;
    _errorMessage = null;
    notifyListeners();

    var succeeded = false;
    try {
      final unsignedPsbt = _sendInfoProvider.txWaitingForSign!;
      final signStart = DateTime.now();
      final signedPsbt = await _signingService.signPsbt(
        walletId: walletId,
        unsignedPsbtBase64: unsignedPsbt,
        secret: secret,
        passphrase: passphrase,
        expectedDescriptor: _expectedDescriptor,
        deviceKeyOverride: deviceKeyOverride,
        preloadedMaterials: _preloadedMaterials,
      );
      Logger.performance('HotWalletSign: signPsbt call=${DateTime.now().difference(signStart).inMilliseconds}ms');
      _sendInfoProvider.setSignedResult(signedPsbt);
      await _keyService.resetFailedAttempts();
      _failedAttempts = 0;
      succeeded = true;
      return true;
    } on HotWalletPassphraseMismatchException {
      _errorMessage = 'passphrase_incorrect';
      if (_usesPassphrase) {
        _failedAttempts = await _keyService.recordFailedAttempt();
      }
      return false;
    } catch (_) {
      _errorMessage = 'sign_failed';
      return false;
    } finally {
      _isSigning = false;
      _preloadedMaterials = null;
      if (succeeded || !_usesPassphrase) {
        clearSensitiveState();
      }
      notifyListeners();
    }
  }

  @visibleForTesting
  void debugSetUsesPassphraseForTest(bool value) => _usesPassphrase = value;
}
