import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/preferences/preference_provider.dart';
import 'package:hotconut_wallet/screens/hot_wallet/mnemonic_backup_screen.dart';
import 'package:hotconut_wallet/utils/clipboard_copy_util.dart';
import 'package:hotconut_wallet/utils/mnemonic_generate_util.dart';
import 'package:hotconut_wallet/utils/secure_screen_util.dart';
import 'package:hotconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:hotconut_wallet/widgets/hot_wallet/mnemonic_length_toggle.dart';
import 'package:hotconut_wallet/widgets/hot_wallet/mnemonic_word_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class MnemonicGenerateScreen extends StatefulWidget {
  const MnemonicGenerateScreen({super.key});

  @override
  State<MnemonicGenerateScreen> createState() => _MnemonicGenerateScreenState();
}

class _MnemonicGenerateScreenState extends State<MnemonicGenerateScreen>
    with SecureScreenMixin, WidgetsBindingObserver {
  static const _bottomButtonAreaHeight = 140.0;

  final Map<int, String> _mnemonicByLength = {};
  final TextEditingController _passphraseController = TextEditingController();
  final FocusNode _passphraseFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _passphraseFieldKey = GlobalKey();
  int _mnemonicLength = 24;
  bool _isGenerating = false;

  String get _mnemonic => _mnemonicByLength[_mnemonicLength] ?? '';

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passphraseFocusNode.dispose();
    _scrollController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _passphraseFocusNode.addListener(_onPassphraseFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _regenerateMnemonic(showOverlay: false);
    });
  }

  @override
  void didChangeMetrics() {
    if (_passphraseFocusNode.hasFocus) {
      _scrollPassphraseIntoView();
    }
  }

  void _onPassphraseFocusChanged() {
    if (!_passphraseFocusNode.hasFocus) return;
    _scrollPassphraseIntoView();
  }

  void _scrollPassphraseIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_passphraseFocusNode.hasFocus) return;
        final fieldContext = _passphraseFieldKey.currentContext;
        if (fieldContext == null || !fieldContext.mounted) return;
        Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  void _unfocus() => FocusScope.of(context).unfocus();

  Future<void> _regenerateMnemonic({required bool showOverlay}) async {
    if (_isGenerating) return;
    _isGenerating = true;
    if (showOverlay) context.loaderOverlay.show();
    try {
      final mnemonic = await generateRandomMnemonic(mnemonicLength: _mnemonicLength);
      if (!mounted) return;
      setState(() => _mnemonicByLength[_mnemonicLength] = mnemonic);
    } finally {
      _isGenerating = false;
      if (showOverlay && mounted) context.loaderOverlay.hide();
    }
  }

  String get _description =>
      _mnemonicLength == 12 ? t.hot_wallet.generate_description_12 : t.hot_wallet.generate_description_24;

  Future<bool?> _showConfirmPopup({required String title, required String description}) {
    return showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: title,
            description: description,
            leftButtonText: t.cancel,
            rightButtonText: t.confirm,
            onTapLeft: () => Navigator.pop(dialogContext, false),
            onTapRight: () => Navigator.pop(dialogContext, true),
          ),
    );
  }

  Future<void> _onRegeneratePressed() async {
    final confirmed = await _showConfirmPopup(
      title: t.hot_wallet.regenerate_confirm_title,
      description: t.hot_wallet.regenerate_confirm_description,
    );
    if (confirmed != true || !mounted) return;
    await _regenerateMnemonic(showOverlay: true);
  }

  Future<void> _onLengthChanged(int length) async {
    if (length == _mnemonicLength || _isGenerating) return;

    if (_mnemonicByLength.containsKey(length)) {
      setState(() => _mnemonicLength = length);
      return;
    }

    setState(() => _mnemonicLength = length);
    await _regenerateMnemonic(showOverlay: true);
  }

  Future<void> _onCopyPressed() async {
    final confirmed = await _showConfirmPopup(
      title: t.hot_wallet.copy_mnemonic,
      description: t.hot_wallet.copy_mnemonic_warning,
    );
    if (confirmed != true || !mounted) return;
    await ClipboardCopyUtil.copyWithToast(context, text: _mnemonic, toastMessage: t.hot_wallet.copy_mnemonic_success);
  }

  Future<void> _onSkipBackupPressed() async {
    final confirmed = await _showConfirmPopup(
      title: t.hot_wallet.skip_backup,
      description: t.hot_wallet.skip_backup_warning,
    );
    if (confirmed != true || !mounted) return;
    _navigateToBackup(skipQuiz: true);
  }

  Future<void> _navigateToBackup({required bool skipQuiz}) async {
    if (_isGenerating || _mnemonic.isEmpty) return;
    context.loaderOverlay.show();
    try {
      final passphrase = _passphraseController.text;
      final vault = await vaultFromMnemonic(_mnemonic, passphrase: passphrase);
      if (!mounted) return;
      _pushBackupScreen(vault, passphrase: passphrase, skipQuiz: skipQuiz);
    } finally {
      if (mounted) context.loaderOverlay.hide();
    }
  }

  void _pushBackupScreen(SingleSignatureVault vault, {required String passphrase, required bool skipQuiz}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => MnemonicBackupScreen(mnemonic: _mnemonic, vault: vault, passphrase: passphrase, skipQuiz: skipQuiz),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMnemonic = _mnemonic.isNotEmpty;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final scrollBottomPadding = _bottomButtonAreaHeight + bottomPadding;

    return CustomLoadingOverlay(
      child: GestureDetector(
        onTap: _unfocus,
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: CoconutColors.black,
          appBar: CoconutAppBar.build(
            title: t.hot_wallet.generate_title,
            context: context,
            actionButtonList: [
              IconButton(
                icon: SvgPicture.asset('assets/svg/arrow-reload.svg', width: 20, height: 20),
                color: CoconutColors.white,
                onPressed: _isGenerating ? null : _onRegeneratePressed,
                tooltip: t.hot_wallet.regenerate_mnemonic,
              ),
            ],
          ),
          body: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0).copyWith(bottom: scrollBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_description, style: CoconutTypography.body2_14),
                      CoconutLayout.spacing_300h,
                      MnemonicLengthToggle(selectedLength: _mnemonicLength, onChanged: _onLengthChanged),
                      CoconutLayout.spacing_300h,
                      Align(
                        alignment: Alignment.centerRight,
                        child: CoconutUnderlinedButton(
                          text: t.hot_wallet.copy_mnemonic,
                          onTap: _onCopyPressed,
                          textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      CoconutLayout.spacing_100h,
                      if (hasMnemonic)
                        MnemonicWordGrid(mnemonic: _mnemonic)
                      else
                        const SizedBox(height: 200, child: Center(child: CoconutCircularIndicator())),
                      CoconutLayout.spacing_300h,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.hot_wallet.passphrase_label, style: CoconutTypography.body2_14),
                      ),
                      CoconutLayout.spacing_100h,
                      TextField(
                        key: _passphraseFieldKey,
                        controller: _passphraseController,
                        focusNode: _passphraseFocusNode,
                        obscureText: true,
                        style: CoconutTypography.body1_16,
                        decoration: InputDecoration(
                          hintText: t.hot_wallet.passphrase_placeholder,
                          hintStyle: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
                          filled: true,
                          fillColor: CoconutColors.gray800,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoconutButton(
                          onPressed: () => _navigateToBackup(skipQuiz: false),
                          isActive: hasMnemonic && !_isGenerating,
                          text: t.next,
                        ),
                        CoconutLayout.spacing_200h,
                        Center(
                          child: CoconutUnderlinedButton(
                            text: t.hot_wallet.skip_backup,
                            onTap: _onSkipBackupPressed,
                            textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
