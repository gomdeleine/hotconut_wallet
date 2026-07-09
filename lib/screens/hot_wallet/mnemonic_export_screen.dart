import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/services/hot_wallet/hot_wallet_key_service.dart';
import 'package:hotconut_wallet/utils/secure_screen_util.dart';
import 'package:hotconut_wallet/widgets/hot_wallet/mnemonic_word_grid.dart';
import 'package:hotconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MnemonicExportScreen extends StatefulWidget {
  final int walletId;

  const MnemonicExportScreen({super.key, required this.walletId});

  @override
  State<MnemonicExportScreen> createState() => _MnemonicExportScreenState();
}

class _MnemonicExportScreenState extends State<MnemonicExportScreen> with SecureScreenMixin {
  String? _mnemonic;
  String? _errorMessage;
  bool _isLoading = true;
  bool _usesPassphrase = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptPinAndLoad());
  }

  Future<void> _promptPinAndLoad() async {
    _usesPassphrase = await HotWalletKeyService().usesPassphrase(widget.walletId);
    if (!mounted) return;

    final pin = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => _MnemonicExportPinScreen()));
    if (!mounted) return;
    if (pin == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final payload = await HotWalletKeyService().unlockSeed(widget.walletId, secret: pin);
      setState(() {
        _mnemonic = payload.mnemonic;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = t.hot_wallet.sign_failed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(title: t.hot_wallet.export_title, context: context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Text(_errorMessage!, style: CoconutTypography.body1_16.setColor(CoconutColors.hotPink))
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.hot_wallet.export_warning,
                        style: CoconutTypography.body2_14.setColor(CoconutColors.hotPink),
                      ),
                      if (_usesPassphrase) ...[
                        CoconutLayout.spacing_200h,
                        Text(
                          t.hot_wallet.export_passphrase_notice,
                          style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                        ),
                      ],
                      CoconutLayout.spacing_400h,
                      Expanded(child: MnemonicWordGrid(mnemonic: _mnemonic!)),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _MnemonicExportPinScreen extends StatefulWidget {
  @override
  State<_MnemonicExportPinScreen> createState() => _MnemonicExportPinScreenState();
}

class _MnemonicExportPinScreenState extends State<_MnemonicExportPinScreen> {
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
    if (value == 'bio') {
      return;
    }
    if (_pin.length >= _authProvider.pinLength) return;
    setState(() => _pin += value);
    if (_pin.length == _authProvider.pinLength) {
      final ok = await _authProvider.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, _pin);
      } else {
        setState(() {
          _errorMessage = t.errors.pin_setting_error.incorrect;
          _pin = '';
          _shuffledPinNumbers = _authProvider.getShuffledNumberPad();
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
