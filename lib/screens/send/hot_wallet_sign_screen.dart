import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/preferences/preference_provider.dart';
import 'package:hotconut_wallet/providers/send_info_provider.dart';
import 'package:hotconut_wallet/providers/view_model/send/hot_wallet_sign_view_model.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/utils/secure_screen_util.dart';
import 'package:hotconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:hotconut_wallet/widgets/dialog.dart';
import 'package:hotconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

enum _SignStep { pin, passphrase }

class HotWalletSignScreen extends StatefulWidget {
  const HotWalletSignScreen({super.key});

  @override
  State<HotWalletSignScreen> createState() => _HotWalletSignScreenState();
}

class _HotWalletSignScreenState extends State<HotWalletSignScreen> with SecureScreenMixin {
  HotWalletSignViewModel? _viewModel;
  String _pin = '';
  String _errorMessage = '';
  List<String> _shuffledPinNumbers = [];
  AuthProvider? _authProvider;
  bool _isReady = false;
  _SignStep _step = _SignStep.pin;

  final TextEditingController _passphraseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    if (!_authProvider!.isSetPin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleMissingPin());
      return;
    }

    _initializeSignScreen();
  }

  @override
  void dispose() {
    _passphraseController.clear();
    _passphraseController.dispose();
    _viewModel?.clearSensitiveState();
    super.dispose();
  }

  Future<void> _initializeSignScreen() async {
    _viewModel = HotWalletSignViewModel(
      context.read<SendInfoProvider>(),
      context.read<WalletProvider>(),
      _authProvider!,
    );
    await _viewModel!.init();
    if (!mounted) return;

    _shuffledPinNumbers = _authProvider!.getShuffledNumberPad(
      isSettings: true,
      showBiometric: _viewModel!.isBiometricAvailable,
    );
    setState(() => _isReady = true);

    if (_viewModel!.isBiometricAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _trySignWithBiometrics());
    }
  }

  Future<void> _trySignWithBiometrics() async {
    if (_viewModel == null || !mounted) return;
    context.loaderOverlay.show();
    final outcome = await _viewModel!.prepareWithBiometrics();
    if (!mounted) return;
    context.loaderOverlay.hide();

    switch (outcome) {
      case HotWalletSignPrepareOutcome.signed:
        await _onSignResult(true);
      case HotWalletSignPrepareOutcome.needPassphrase:
        setState(() {
          _step = _SignStep.passphrase;
          _errorMessage = '';
        });
      case HotWalletSignPrepareOutcome.failed:
        break;
    }
  }

  Future<void> _handleMissingPin() async {
    if (!mounted) return;
    await showInfoDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.hot_wallet.pin_required_title,
      t.hot_wallet.pin_required_description,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onSignResult(bool ok) async {
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacementNamed(context, '/broadcasting');
    }
  }

  Future<void> _onKeyTap(String value) async {
    if (_viewModel == null || _authProvider == null) return;
    if (_viewModel!.isSigning) return;

    if (value == 'bio') {
      await _trySignWithBiometrics();
      return;
    }

    final pinLength = _authProvider!.effectivePinLength;

    if (value == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }

    if (_pin.length >= pinLength) return;
    setState(() => _pin += value);

    if (_pin.length == pinLength) {
      context.loaderOverlay.show();
      final outcome = await _viewModel!.verifyPinAndPrepare(_pin);
      if (!mounted) return;
      context.loaderOverlay.hide();

      switch (outcome) {
        case HotWalletSignPrepareOutcome.signed:
          await _onSignResult(true);
        case HotWalletSignPrepareOutcome.needPassphrase:
          setState(() {
            _step = _SignStep.passphrase;
            _errorMessage = '';
            _pin = '';
          });
        case HotWalletSignPrepareOutcome.failed:
          setState(() {
            _errorMessage =
                _viewModel!.errorMessage == 'pin_incorrect'
                    ? t.errors.pin_check_error.incorrect
                    : t.hot_wallet.sign_failed;
            _pin = '';
            _shuffledPinNumbers = _authProvider!.getShuffledNumberPad(
              isSettings: true,
              showBiometric: _viewModel!.isBiometricAvailable,
            );
          });
      }
    }
  }

  Future<void> _onSubmitPassphrase() async {
    if (_viewModel == null || _viewModel!.isSigning) return;
    final passphrase = _passphraseController.text;

    context.loaderOverlay.show();
    final ok = await _viewModel!.signWithPassphrase(passphrase);
    if (!mounted) return;
    context.loaderOverlay.hide();

    _passphraseController.clear();

    if (ok) {
      await _onSignResult(true);
      return;
    }

    setState(() {
      _errorMessage = t.hot_wallet.passphrase_incorrect;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomLoadingOverlay(child: _buildContent());
  }

  Widget _buildContent() {
    if (!_isReady || _viewModel == null || _authProvider == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (_step == _SignStep.passphrase) {
      return _buildPassphraseView();
    }

    return ChangeNotifierProvider.value(
      value: _viewModel!,
      child: PinInputPad(
        title: t.hot_wallet.sign_description,
        pin: _pin,
        errorMessage: _errorMessage,
        onKeyTap: _onKeyTap,
        pinShuffleNumbers: _shuffledPinNumbers,
        onClosePressed: () => Navigator.pop(context),
        step: 0,
        pinLength: _authProvider!.effectivePinLength,
      ),
    );
  }

  Widget _buildPassphraseView() {
    return ListenableBuilder(
      listenable: _viewModel!,
      builder: (context, _) {
        final isSigning = _viewModel!.isSigning;

        return Scaffold(
          backgroundColor: CoconutColors.black,
          appBar: CoconutAppBar.build(title: t.hot_wallet.sign_passphrase_title, context: context),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.hot_wallet.sign_passphrase_description,
                    style: CoconutTypography.body2_14.setColor(CoconutColors.gray300),
                  ),
                  CoconutLayout.spacing_400h,
                  TextField(
                    controller: _passphraseController,
                    autofocus: true,
                    obscureText: true,
                    enabled: !isSigning,
                    style: CoconutTypography.body1_16,
                    onChanged: (_) => setState(() => _errorMessage = ''),
                    decoration: InputDecoration(
                      hintText: t.hot_wallet.passphrase_placeholder,
                      filled: true,
                      fillColor: CoconutColors.gray800,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    CoconutLayout.spacing_200h,
                    Text(_errorMessage, style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink)),
                  ],
                  if (_viewModel!.failedAttempts > 0) ...[
                    CoconutLayout.spacing_100h,
                    Text(
                      t.hot_wallet.passphrase_failed_attempts(count: _viewModel!.failedAttempts),
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                    ),
                  ],
                  const Spacer(),
                  CoconutButton(onPressed: _onSubmitPassphrase, isActive: !isSigning, text: t.confirm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
