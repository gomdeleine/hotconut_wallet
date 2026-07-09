import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/enums/wallet_enums.dart';
import 'package:hotconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/send_info_provider.dart';
import 'package:hotconut_wallet/providers/view_model/send/hot_wallet_sign_view_model.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_encryption.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_signing_service.dart';
import 'package:hotconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthProvider extends Fake implements AuthProvider {
  _FakeAuthProvider({this.verifyResult = true, this.biometricsEnabled = false, this.deviceKeyResult});

  final bool verifyResult;
  final bool biometricsEnabled;
  final List<int>? deviceKeyResult;
  String? lastVerifiedPin;

  @override
  bool get isBiometricsAuthEnabled => biometricsEnabled;

  @override
  Future<bool> verifyPin(String inputPin) async {
    lastVerifiedPin = inputPin;
    return verifyResult;
  }

  @override
  Future<List<int>?> unlockHotWalletDeviceKeyWithBiometrics() async => deviceKeyResult;
}

class _FakeKeyService extends Fake implements HotWalletKeyService {
  _FakeKeyService({this.usesPassphraseFlag = false});

  final bool usesPassphraseFlag;
  List<int>? storedBiometricKey;
  String? enabledWith;
  int recordedFailures = 0;
  bool didReset = false;

  @override
  Future<bool> usesPassphrase(int walletId) async => usesPassphraseFlag;

  @override
  Future<int> getFailedAttempts() async => 0;

  @override
  Future<List<int>?> readBiometricDeviceKey() async => storedBiometricKey;

  @override
  Future<void> enableBiometricFastPath(String secret) async {
    enabledWith = secret;
    storedBiometricKey = [1, 2, 3];
  }

  @override
  Future<void> resetFailedAttempts() async {
    didReset = true;
  }

  @override
  Future<int> recordFailedAttempt() async => ++recordedFailures;
}

class _FakeSendInfoProvider extends Fake implements SendInfoProvider {
  _FakeSendInfoProvider(this._walletId, this._unsignedPsbt);

  final int _walletId;
  final String _unsignedPsbt;
  String? signedResult;

  @override
  int? get walletId => _walletId;

  @override
  String? get txWaitingForSign => _unsignedPsbt;

  @override
  void setSignedResult(String signedPsbt) {
    signedResult = signedPsbt;
  }
}

class _FakeWalletProvider extends Fake implements WalletProvider {
  _FakeWalletProvider(this._item);

  final WalletListItemBase _item;

  @override
  WalletListItemBase getWalletById(int id) => _item;
}

class _RecordingSigningService extends HotWalletSigningService {
  _RecordingSigningService(this._handler);

  final Future<String> Function({
    required int walletId,
    required String unsignedPsbtBase64,
    required String secret,
    String passphrase,
    String? expectedDescriptor,
    List<int>? deviceKeyOverride,
    HotWalletUnlockMaterials? preloadedMaterials,
  })
  _handler;
  int callCount = 0;
  List<int>? lastDeviceKeyOverride;
  String? lastSecret;
  String? lastPassphrase;

  @override
  Future<String> signPsbt({
    required int walletId,
    required String unsignedPsbtBase64,
    required String secret,
    String passphrase = '',
    String? expectedDescriptor,
    List<int>? deviceKeyOverride,
    HotWalletUnlockMaterials? preloadedMaterials,
  }) async {
    callCount += 1;
    lastDeviceKeyOverride = deviceKeyOverride;
    lastSecret = secret;
    lastPassphrase = passphrase;
    return _handler(
      walletId: walletId,
      unsignedPsbtBase64: unsignedPsbtBase64,
      secret: secret,
      passphrase: passphrase,
      expectedDescriptor: expectedDescriptor,
      deviceKeyOverride: deviceKeyOverride,
      preloadedMaterials: preloadedMaterials,
    );
  }
}

_RecordingSigningService _signingReturning(String signed) {
  return _RecordingSigningService(
    ({
      required walletId,
      required unsignedPsbtBase64,
      required secret,
      passphrase = '',
      expectedDescriptor,
      deviceKeyOverride,
      preloadedMaterials,
    }) async => signed,
  );
}

void main() {
  group('HotWalletSignViewModel', () {
    const pin = '123456';
    const unsignedPsbt = 'cHNidP8=';
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    late String testDescriptor;

    setUpAll(() {
      NetworkType.setNetworkType(NetworkType.regtest);
      testDescriptor = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(mnemonic))).descriptor;
    });

    HotWalletSignViewModel buildViewModel({
      required _FakeAuthProvider authProvider,
      required _RecordingSigningService signingService,
      _FakeKeyService? keyService,
      _FakeSendInfoProvider? sendInfoProvider,
      bool usesPassphrase = false,
      WalletListItemBase? walletItem,
    }) {
      final item =
          walletItem ??
          SinglesigWalletListItem(
            id: 1,
            name: 'test',
            descriptor: testDescriptor,
            colorIndex: 0,
            iconIndex: 0,
            walletImportSource: WalletImportSource.hotWallet,
          );
      final viewModel = HotWalletSignViewModel(
        sendInfoProvider ?? _FakeSendInfoProvider(1, unsignedPsbt),
        _FakeWalletProvider(item),
        authProvider,
        signingService: signingService,
        keyService: keyService ?? _FakeKeyService(usesPassphraseFlag: usesPassphrase),
      );
      viewModel.debugSetUsesPassphraseForTest(usesPassphrase);
      return viewModel;
    }

    test('verifyPinAndPrepare returns failed when pin is invalid', () async {
      final authProvider = _FakeAuthProvider(verifyResult: false);
      final signingService = _signingReturning('signed');
      final viewModel = buildViewModel(authProvider: authProvider, signingService: signingService);

      final outcome = await viewModel.verifyPinAndPrepare(pin);

      expect(outcome, HotWalletSignPrepareOutcome.failed);
      expect(viewModel.errorMessage, 'pin_incorrect');
      expect(signingService.callCount, 0);
      expect(authProvider.lastVerifiedPin, pin);
    });

    test('verifyPinAndPrepare signs immediately when wallet has no passphrase', () async {
      final authProvider = _FakeAuthProvider(verifyResult: true);
      final signingService = _signingReturning('signed');
      final sendInfo = _FakeSendInfoProvider(1, unsignedPsbt);
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        sendInfoProvider: sendInfo,
      );

      final outcome = await viewModel.verifyPinAndPrepare(pin);

      expect(outcome, HotWalletSignPrepareOutcome.signed);
      expect(signingService.callCount, 1);
      expect(signingService.lastSecret, pin);
      expect(sendInfo.signedResult, 'signed');
    });

    test('verifyPinAndPrepare returns needPassphrase for passphrase wallet', () async {
      final authProvider = _FakeAuthProvider(verifyResult: true);
      final signingService = _signingReturning('signed');
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        usesPassphrase: true,
      );

      final outcome = await viewModel.verifyPinAndPrepare(pin);

      expect(outcome, HotWalletSignPrepareOutcome.needPassphrase);
      expect(signingService.callCount, 0);
    });

    test('signWithPassphrase signs with pin and passphrase', () async {
      final authProvider = _FakeAuthProvider(verifyResult: true);
      final signingService = _signingReturning('signed');
      final sendInfo = _FakeSendInfoProvider(1, unsignedPsbt);
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        sendInfoProvider: sendInfo,
        usesPassphrase: true,
      );

      await viewModel.verifyPinAndPrepare(pin);
      final ok = await viewModel.signWithPassphrase('secret');

      expect(ok, isTrue);
      expect(signingService.callCount, 1);
      expect(signingService.lastSecret, pin);
      expect(signingService.lastPassphrase, 'secret');
      expect(sendInfo.signedResult, 'signed');
    });

    test('verifyPinAndPrepare enables biometric fast path when biometrics enabled and no key stored', () async {
      final authProvider = _FakeAuthProvider(verifyResult: true, biometricsEnabled: true);
      final signingService = _signingReturning('signed');
      final keyService = _FakeKeyService();
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        keyService: keyService,
      );

      await viewModel.verifyPinAndPrepare(pin);

      expect(keyService.enabledWith, pin);
    });

    test('prepareWithBiometrics returns failed when device key is unavailable', () async {
      final authProvider = _FakeAuthProvider(deviceKeyResult: null, biometricsEnabled: true);
      final signingService = _signingReturning('signed');
      final viewModel = buildViewModel(authProvider: authProvider, signingService: signingService);

      final outcome = await viewModel.prepareWithBiometrics();

      expect(outcome, HotWalletSignPrepareOutcome.failed);
      expect(signingService.callCount, 0);
    });

    test('prepareWithBiometrics signs with device key override when available', () async {
      final authProvider = _FakeAuthProvider(deviceKeyResult: [9, 9, 9], biometricsEnabled: true);
      final signingService = _signingReturning('signed');
      final sendInfo = _FakeSendInfoProvider(1, unsignedPsbt);
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        sendInfoProvider: sendInfo,
      );

      final outcome = await viewModel.prepareWithBiometrics();

      expect(outcome, HotWalletSignPrepareOutcome.signed);
      expect(signingService.callCount, 1);
      expect(signingService.lastDeviceKeyOverride, [9, 9, 9]);
      expect(sendInfo.signedResult, 'signed');
      expect(authProvider.lastVerifiedPin, isNull);
    });

    test('passphrase wallet counts failures on passphrase mismatch', () async {
      final authProvider = _FakeAuthProvider(verifyResult: true);
      final signingService = _RecordingSigningService(
        ({
          required walletId,
          required unsignedPsbtBase64,
          required secret,
          passphrase = '',
          expectedDescriptor,
          deviceKeyOverride,
          preloadedMaterials,
        }) async => throw HotWalletPassphraseMismatchException(),
      );
      final keyService = _FakeKeyService(usesPassphraseFlag: true);
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        keyService: keyService,
        usesPassphrase: true,
      );

      await viewModel.verifyPinAndPrepare(pin);
      final ok = await viewModel.signWithPassphrase('wrong');

      expect(ok, isFalse);
      expect(viewModel.errorMessage, 'passphrase_incorrect');
      expect(keyService.recordedFailures, 1);
    });

    test('passphrase wallet counts consecutive failures on retry', () async {
      final authProvider = _FakeAuthProvider(verifyResult: true);
      final signingService = _RecordingSigningService(
        ({
          required walletId,
          required unsignedPsbtBase64,
          required secret,
          passphrase = '',
          expectedDescriptor,
          deviceKeyOverride,
          preloadedMaterials,
        }) async => throw HotWalletPassphraseMismatchException(),
      );
      final keyService = _FakeKeyService(usesPassphraseFlag: true);
      final viewModel = buildViewModel(
        authProvider: authProvider,
        signingService: signingService,
        keyService: keyService,
        usesPassphrase: true,
      );

      await viewModel.verifyPinAndPrepare(pin);

      final firstOk = await viewModel.signWithPassphrase('wrong1');
      expect(firstOk, isFalse);
      expect(viewModel.errorMessage, 'passphrase_incorrect');
      expect(keyService.recordedFailures, 1);
      expect(signingService.lastSecret, pin);

      final secondOk = await viewModel.signWithPassphrase('wrong2');
      expect(secondOk, isFalse);
      expect(viewModel.errorMessage, 'passphrase_incorrect');
      expect(keyService.recordedFailures, 2);
      expect(signingService.callCount, 2);
      expect(signingService.lastSecret, pin);
      expect(signingService.lastPassphrase, 'wrong2');
    });
  });
}
