import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/screens/hot_wallet/mnemonic_backup_screen.dart';
import 'package:hotconut_wallet/utils/mnemonic_scan_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MnemonicImportScreen extends StatefulWidget {
  const MnemonicImportScreen({super.key});

  @override
  State<MnemonicImportScreen> createState() => _MnemonicImportScreenState();
}

class _MnemonicImportScreenState extends State<MnemonicImportScreen> {
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _mnemonicController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _onScanQrPressed() async {
    final scanned = await showMnemonicQrScannerBottomSheet(context, title: t.hot_wallet.scan_mnemonic_qr_title);
    if (scanned == null || !mounted) return;
    setState(() {
      _mnemonicController.text = scanned;
      _errorMessage = null;
    });
  }

  void _onContinue() {
    final mnemonic = normalizeMnemonicText(_mnemonicController.text);
    final passphrase = _passphraseController.text;

    try {
      final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
      final passphraseBytes = passphrase.isEmpty ? null : Uint8List.fromList(utf8.encode(passphrase));
      final vault = SingleSignatureVault.fromMnemonic(mnemonicBytes, passphrase: passphraseBytes);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => MnemonicBackupScreen(mnemonic: mnemonic, vault: vault, passphrase: passphrase, skipQuiz: true),
        ),
      );
    } catch (_) {
      setState(() => _errorMessage = t.hot_wallet.invalid_mnemonic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
        title: t.hot_wallet.import_title,
        context: context,
        actionButtonList: [
          IconButton(
            icon: SvgPicture.asset('assets/svg/scan.svg', width: 20, height: 20),
            color: CoconutColors.white,
            onPressed: _onScanQrPressed,
            tooltip: t.hot_wallet.scan_mnemonic_qr,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CoconutUnderlinedButton(
                  text: t.hot_wallet.scan_mnemonic_qr,
                  onTap: _onScanQrPressed,
                  textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                  padding: EdgeInsets.zero,
                ),
              ),
              CoconutLayout.spacing_200h,
              TextField(
                controller: _mnemonicController,
                maxLines: 4,
                style: CoconutTypography.body1_16,
                decoration: InputDecoration(
                  hintText: t.hot_wallet.import_placeholder,
                  hintStyle: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
                  filled: true,
                  fillColor: CoconutColors.gray800,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              CoconutLayout.spacing_300h,
              Align(
                alignment: Alignment.centerLeft,
                child: Text(t.hot_wallet.passphrase_label, style: CoconutTypography.body2_14),
              ),
              CoconutLayout.spacing_100h,
              TextField(
                controller: _passphraseController,
                obscureText: true,
                style: CoconutTypography.body1_16,
                decoration: InputDecoration(
                  hintText: t.hot_wallet.passphrase_placeholder,
                  hintStyle: CoconutTypography.body2_14.setColor(CoconutColors.gray500),
                  filled: true,
                  fillColor: CoconutColors.gray800,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (_errorMessage != null) ...[
                CoconutLayout.spacing_200h,
                Text(_errorMessage!, style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink)),
              ],
              const Spacer(),
              CoconutButton(onPressed: _onContinue, text: t.next),
            ],
          ),
        ),
      ),
    );
  }
}
