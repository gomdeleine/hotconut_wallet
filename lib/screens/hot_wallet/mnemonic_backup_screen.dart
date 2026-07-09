import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/enums/wallet_enums.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/preferences/preference_provider.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/services/wallet_add_service.dart';
import 'package:hotconut_wallet/utils/alert_util.dart';
import 'package:hotconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:hotconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class MnemonicBackupScreen extends StatefulWidget {
  final String mnemonic;
  final SingleSignatureVault vault;
  final String passphrase;
  final bool skipQuiz;

  const MnemonicBackupScreen({
    super.key,
    required this.mnemonic,
    required this.vault,
    this.passphrase = '',
    this.skipQuiz = false,
  });

  @override
  State<MnemonicBackupScreen> createState() => _MnemonicBackupScreenState();
}

class _MnemonicBackupScreenState extends State<MnemonicBackupScreen> {
  final TextEditingController _walletNameController = TextEditingController(text: '');
  final TextEditingController _quizAnswerController = TextEditingController();
  final Random _random = Random.secure();

  late final List<int> _quizPositions;
  int _quizIndex = 0;
  late bool _quizPassed;
  String? _quizError;

  bool get _usesPassphrase => widget.passphrase.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _quizPassed = widget.skipQuiz;
    _walletNameController.text = t.hot_wallet.wallet_name_placeholder;
    final words = widget.mnemonic.split(' ');
    final positions = List<int>.generate(words.length, (i) => i);
    positions.shuffle(_random);
    _quizPositions = positions.take(3).toList()..sort();
  }

  @override
  void dispose() {
    _walletNameController.dispose();
    _quizAnswerController.dispose();
    super.dispose();
  }

  int get _currentQuizPosition => _quizPositions[_quizIndex] + 1;

  String get _expectedAnswer => widget.mnemonic.split(' ')[_quizPositions[_quizIndex]];

  Future<bool?> _showSkipBackupPopup() {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.hot_wallet.skip_backup,
            description: t.hot_wallet.skip_backup_warning,
            leftButtonText: t.cancel,
            rightButtonText: t.confirm,
            onTapLeft: () => Navigator.pop(dialogContext, false),
            onTapRight: () => Navigator.pop(dialogContext, true),
          ),
    );
  }

  Future<void> _onSkipBackupPressed() async {
    final confirmed = await _showSkipBackupPopup();
    if (confirmed != true || !mounted) return;
    setState(() {
      _quizPassed = true;
      _quizError = null;
      _quizAnswerController.clear();
    });
  }

  void _submitQuizAnswer() {
    if (_quizAnswerController.text.trim().toLowerCase() != _expectedAnswer.toLowerCase()) {
      setState(() {
        _quizError = t.hot_wallet.backup_quiz_failed;
        _quizAnswerController.clear();
      });
      return;
    }

    if (_quizIndex < _quizPositions.length - 1) {
      setState(() {
        _quizIndex++;
        _quizError = null;
        _quizAnswerController.clear();
      });
      return;
    }

    setState(() {
      _quizPassed = true;
      _quizError = null;
    });
  }

  Future<void> _createWallet() async {
    final pin = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => _HotWalletCreatePinScreen()));
    if (!mounted || pin == null) return;

    context.loaderOverlay.show();
    try {
      final walletProvider = context.read<WalletProvider>();
      final watchOnlyWallet = WalletAddService().createHotWalletFromVault(
        vault: widget.vault,
        name: _walletNameController.text.trim(),
      );
      final result = await walletProvider.addHotWallet(
        watchOnlyWallet: watchOnlyWallet,
        mnemonic: widget.mnemonic,
        secret: pin,
        usesPassphrase: _usesPassphrase,
      );
      if (!mounted) return;

      if (result.result == WalletSyncResult.newWalletAdded) {
        final authProvider = context.read<AuthProvider>();
        if (authProvider.isBiometricsAuthEnabled) {
          await authProvider.enableHotWalletBiometricFastPath(pin);
        }
        if (!mounted) return;
        context.loaderOverlay.hide();
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      context.loaderOverlay.hide();
      showAlertDialog(
        context: context,
        title: t.alert.wallet_add.add_failed,
        content: t.alert.wallet_add.duplicate_name_description,
      );
    } catch (e) {
      if (mounted) context.loaderOverlay.hide();
      if (!mounted) return;
      showAlertDialog(context: context, title: t.alert.wallet_add.add_failed, content: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomLoadingOverlay(
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: CoconutAppBar.build(
          title: widget.skipQuiz ? t.hot_wallet.wallet_name_label : t.hot_wallet.backup_title,
          context: context,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _quizPassed ? t.hot_wallet.wallet_name_label : t.hot_wallet.backup_quiz_title,
                  style: CoconutTypography.heading4_18,
                ),
                CoconutLayout.spacing_200h,
                if (!_quizPassed) ...[
                  Text(
                    t.hot_wallet.backup_quiz_prompt(position: _currentQuizPosition),
                    style: CoconutTypography.body1_16,
                  ),
                  CoconutLayout.spacing_200h,
                  TextField(
                    controller: _quizAnswerController,
                    style: CoconutTypography.body1_16,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: CoconutColors.gray800,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _submitQuizAnswer(),
                  ),
                  if (_quizError != null) ...[
                    CoconutLayout.spacing_100h,
                    Text(_quizError!, style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink)),
                  ],
                  const Spacer(),
                  CoconutButton(onPressed: _submitQuizAnswer, text: t.confirm),
                  CoconutLayout.spacing_200h,
                  Center(
                    child: CoconutUnderlinedButton(
                      text: t.hot_wallet.skip_backup,
                      onTap: _onSkipBackupPressed,
                      textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ] else ...[
                  if (_usesPassphrase) ...[
                    Text(
                      t.hot_wallet.passphrase_wallet_notice,
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                    ),
                    CoconutLayout.spacing_200h,
                  ],
                  TextField(
                    controller: _walletNameController,
                    style: CoconutTypography.body1_16,
                    decoration: InputDecoration(
                      hintText: t.hot_wallet.wallet_name_placeholder,
                      filled: true,
                      fillColor: CoconutColors.gray800,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const Spacer(),
                  CoconutButton(onPressed: _createWallet, text: t.complete),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HotWalletCreatePinScreen extends StatefulWidget {
  @override
  State<_HotWalletCreatePinScreen> createState() => _HotWalletCreatePinScreenState();
}

class _HotWalletCreatePinScreenState extends State<_HotWalletCreatePinScreen> {
  String _pin = '';
  String _errorMessage = '';
  late List<String> _shuffledPinNumbers;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
  }

  Future<void> _onKeyTap(String value) async {
    if (value == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (value == 'bio') return;
    if (_pin.length >= _authProvider.pinLength) return;
    setState(() => _pin += value);
    if (_pin.length == _authProvider.pinLength) {
      final ok = await _authProvider.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, _pin);
      } else {
        setState(() {
          _errorMessage = t.errors.pin_check_error.incorrect;
          _pin = '';
          _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PinInputPad(
      title: t.hot_wallet.sign_description,
      pin: _pin,
      errorMessage: _errorMessage,
      onKeyTap: _onKeyTap,
      pinShuffleNumbers: _shuffledPinNumbers,
      onClosePressed: () => Navigator.pop(context),
      step: 0,
      pinLength: _authProvider.pinLength,
    );
  }
}
