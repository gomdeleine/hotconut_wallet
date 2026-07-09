import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/screens/hot_wallet/mnemonic_generate_screen.dart';
import 'package:hotconut_wallet/screens/hot_wallet/mnemonic_import_screen.dart';
import 'package:hotconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';

class HotWalletOnboardingScreen extends StatelessWidget {
  const HotWalletOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(title: t.hot_wallet.onboarding_title, context: context),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoconutLayout.spacing_300h,
                  Text(t.hot_wallet.onboarding_description, style: CoconutTypography.body1_16),
                ],
              ),
            ),
            FixedBottomButton(
              onButtonClicked: () => _showCreateOptions(context),
              text: t.hot_wallet.create_hot_wallet,
              backgroundColor: CoconutColors.gray100,
              pressedBackgroundColor: CoconutColors.gray500,
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CoconutColors.gray900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(t.hot_wallet.create_new, style: CoconutTypography.body1_16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MnemonicGenerateScreen()));
                  },
                ),
                ListTile(
                  title: Text(t.hot_wallet.import_existing, style: CoconutTypography.body1_16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MnemonicImportScreen()));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
