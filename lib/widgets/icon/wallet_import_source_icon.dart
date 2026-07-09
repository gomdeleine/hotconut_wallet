import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hotconut_wallet/constants/icon_path.dart';
import 'package:hotconut_wallet/enums/wallet_enums.dart';

class WalletImportSourceIcon extends StatelessWidget {
  final WalletImportSource walletImportSource;
  final double? width;
  final double? height;
  final ColorFilter? colorFilter;

  const WalletImportSourceIcon({
    super.key,
    required this.walletImportSource,
    this.width,
    this.height,
    this.colorFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (walletImportSource == WalletImportSource.hotWallet) {
      final size = width ?? height ?? 18.0;
      return Image.asset(kHotWalletIconPath, width: width ?? size, height: height ?? size, fit: BoxFit.contain);
    }

    return SvgPicture.asset(
      walletImportSource.externalWalletIconPath,
      width: width,
      height: height,
      colorFilter: colorFilter,
    );
  }
}
