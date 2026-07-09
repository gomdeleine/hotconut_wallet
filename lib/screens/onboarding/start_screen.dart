import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/app.dart';
import 'package:hotconut_wallet/main.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:hotconut_wallet/providers/visibility_provider.dart';
import 'package:hotconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StartScreen extends StatefulWidget {
  final void Function(AppEntryFlow nextScreen) onComplete;

  const StartScreen({super.key, required this.onComplete});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late StartViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color:
          Platform.isIOS
              ? CoconutColors.black
              : (NetworkType.currentNetworkType.isTestnet
                  ? splashBackgroundColorRegtest
                  : splashBackgroundColorMainnet),
      child: Center(
        child: Image.asset(
          'assets/images/splash_logo_${NetworkType.currentNetworkType.isTestnet ? "regtest" : "mainnet"}.png',
          width: Sizes.size60,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _viewModel = StartViewModel(
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<AuthProvider>(context, listen: false),
    );

    _initialize();
  }

  @override
  void dispose() {
    super.dispose();
    if (Platform.isAndroid) {
      setSystemBarColor(CoconutColors.black);
    }
  }

  void _initialize() async {
    await Future.delayed(const Duration(seconds: 1));
    final AppEntryFlow nextScreen = await _viewModel.determineStartScreen();
    widget.onComplete(nextScreen);
  }
}
