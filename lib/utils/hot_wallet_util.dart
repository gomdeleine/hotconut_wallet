import 'package:hotconut_wallet/enums/wallet_enums.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/providers/preferences/preference_provider.dart';
import 'package:hotconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:hotconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:hotconut_wallet/widgets/dialog.dart';
import 'package:hotconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

bool hasHotWallet(WalletProvider walletProvider) {
  return walletProvider.walletItemList.any((wallet) => wallet.walletImportSource == WalletImportSource.hotWallet);
}

/// 핫월렛 생성 플로우 진입 전 PIN 설정 여부를 확인합니다.
/// PIN이 설정되어 있거나 설정에 성공하면 `true`, 취소 시 `false`를 반환합니다.
Future<bool> ensureHotWalletPinSet(BuildContext context) async {
  if (context.read<AuthProvider>().isSetPin) return true;

  final languageCode = context.read<PreferenceProvider>().language;
  var shouldSetPin = false;

  await showConfirmDialog(
    context,
    languageCode,
    t.hot_wallet.pin_required_title,
    t.hot_wallet.pin_required_description,
    leftButtonText: t.cancel,
    rightButtonText: t.hot_wallet.set_pin,
    barrierDismissible: false,
    onTapLeft: () => Navigator.pop(context),
    onTapRight: () {
      shouldSetPin = true;
      Navigator.pop(context);
    },
  );

  if (!context.mounted) return false;
  if (!shouldSetPin) return false;

  await CommonBottomSheets.showCustomHeightBottomSheet(
    context: context,
    heightRatio: 0.9,
    child: const CustomLoadingOverlay(child: PinSettingScreen(useBiometrics: true)),
  );

  if (!context.mounted) return false;
  return context.read<AuthProvider>().isSetPin;
}
