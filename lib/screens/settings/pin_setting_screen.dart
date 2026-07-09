import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:hotconut_wallet/utils/hash_util.dart';
import 'package:flutter/material.dart';
import 'package:hotconut_wallet/utils/vibration_util.dart';
import 'package:hotconut_wallet/widgets/animated_dialog.dart';
import 'package:hotconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:hotconut_wallet/widgets/pin/pin_length_toggle_button.dart';
import 'package:provider/provider.dart';

class PinSettingScreen extends StatefulWidget {
  final bool useBiometrics;
  const PinSettingScreen({super.key, this.useBiometrics = false});

  @override
  State<PinSettingScreen> createState() => _PinSettingScreenState();
}

class _PinSettingScreenState extends State<PinSettingScreen> {
  int step = 0;
  late String pin;
  late String pinConfirm;
  late String errorMessage;
  late int _pinLength;
  late List<String> _shuffledPinNumbers;
  late AuthProvider _authProvider;
  late bool _isChangingPin;
  String _oldPin = '';

  int get _confirmStep => _isChangingPin ? 2 : 1;

  @override
  void initState() {
    super.initState();
    pin = '';
    pinConfirm = '';
    errorMessage = '';
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isChangingPin = _authProvider.isSetPin;
    _pinLength = _authProvider.pinLength == 0 ? 4 : _authProvider.pinLength;
    _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
  }

  void _shufflePinNumbers() {
    setState(() {
      _shuffledPinNumbers = _authProvider.getShuffledNumberPad(isSettings: true);
    });
  }

  Future<void> _showPinSetSuccessLottie() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation animation, Animation secondaryAnimation) {
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (buildContext.mounted) {
            Navigator.of(buildContext).pop();
          }
        });

        return AnimatedDialog(
          context: buildContext,
          lottieAddress: 'assets/lottie/pin-locked-success.json',
          duration: 400,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ).drive(Tween<Offset>(begin: const Offset(0, 1), end: const Offset(0, 0))),
          child: child,
        );
      },
    );
  }

  void returnToBackSequence(String message, {bool isError = false, bool firstSequence = false}) {
    setState(() {
      errorMessage = message;
      pinConfirm = '';
      _shufflePinNumbers();
      if (firstSequence) {
        step = 0;
        pin = '';
        _oldPin = '';
      }
    });
    if (isError) {
      vibrateMedium();
      return;
    }

    vibrateLightDouble();
  }

  Future<void> _onOldPinComplete() async {
    try {
      final isValid = await _authProvider.verifyPin(pin);
      if (!isValid) {
        returnToBackSequence(t.errors.pin_check_error.incorrect, isError: true, firstSequence: true);
        return;
      }

      setState(() {
        _oldPin = pin;
        pin = '';
        step = 1;
        errorMessage = '';
        _shufflePinNumbers();
      });
    } catch (_) {
      returnToBackSequence(t.errors.pin_setting_error.process_failed, isError: true);
    }
  }

  Future<void> _onNewPinComplete() async {
    if (_isChangingPin && pin == _oldPin) {
      returnToBackSequence(t.errors.pin_setting_error.already_in_use, firstSequence: true);
      return;
    }

    setState(() {
      step = _confirmStep;
      errorMessage = '';
      pinConfirm = '';
      _shufflePinNumbers();
    });
  }

  Future<void> _onConfirmComplete() async {
    if (pinConfirm != pin) {
      returnToBackSequence(t.errors.pin_setting_error.incorrect, isError: true, firstSequence: true);
      return;
    }

    try {
      if (_isChangingPin) {
        await HotWalletKeyService().changeSecret(oldSecret: _oldPin, newSecret: pin);
      }

      final hashedPin = generateHashString(pin);
      await _authProvider.savePinSet(hashedPin, pin.length);

      if (widget.useBiometrics && _authProvider.canCheckBiometrics) {
        await _authProvider.authenticateWithBiometrics(isSave: true);
        await _authProvider.checkDeviceBiometrics();
      }

      if (_authProvider.isSetBiometrics) {
        await _authProvider.enableHotWalletBiometricFastPath(pin);
      }

      vibrateLight();
      await _showPinSetSuccessLottie();

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      returnToBackSequence(t.errors.pin_setting_error.save_failed, isError: true, firstSequence: true);
    }
  }

  void _onKeyTap(String value) async {
    setState(() {
      errorMessage = '';
    });

    if (step == _confirmStep) {
      if (value == '<') {
        if (pinConfirm.isNotEmpty) {
          setState(() => pinConfirm = pinConfirm.substring(0, pinConfirm.length - 1));
        }
      } else if (pinConfirm.length < pin.length) {
        setState(() => pinConfirm += value);
        vibrateExtraLight();
      }

      if (pinConfirm.length == pin.length) {
        await _onConfirmComplete();
      }
      return;
    }

    if (value == '<') {
      if (pin.isNotEmpty) {
        setState(() => pin = pin.substring(0, pin.length - 1));
      }
      return;
    }

    if (pin.length < _pinLength) {
      setState(() => pin += value);
      vibrateExtraLight();
    }

    if (pin.length != _pinLength) {
      return;
    }

    if (_isChangingPin && step == 0) {
      await _onOldPinComplete();
      return;
    }

    await _onNewPinComplete();
  }

  String _titleForStep() {
    if (_isChangingPin && step == 0) {
      return t.pin_check_screen.text;
    }
    if (step == _confirmStep) {
      return t.pin_setting_screen.enter_again;
    }
    return t.pin_setting_screen.new_password;
  }

  @override
  Widget build(BuildContext context) {
    Widget? centerWidget;
    if (!_isChangingPin && step == 0) {
      centerWidget = PinLengthToggleButton(
        currentPinLength: _pinLength,
        onToggle: () {
          setState(() {
            _pinLength = _pinLength == 4 ? 6 : 4;
            pin = '';
          });
        },
      );
    }

    return Scaffold(
      body: PinInputPad(
        title: _titleForStep(),
        pin: step == _confirmStep ? pinConfirm : pin,
        errorMessage: errorMessage,
        onKeyTap: _onKeyTap,
        pinShuffleNumbers: _shuffledPinNumbers,
        onClosePressed: () => Navigator.pop(context),
        onBackPressed:
            step > 0
                ? () {
                  setState(() {
                    step -= 1;
                    pin = step == 0 ? '' : pin;
                    pinConfirm = '';
                    errorMessage = '';
                  });
                }
                : null,
        step: step,
        pinLength: _pinLength,
        appBarVisible: true,
        initOptionVisible: false,
        centerWidget: centerWidget,
      ),
    );
  }
}
