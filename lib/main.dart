import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/constants/dotenv_keys.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/utils/file_logger.dart';
import 'package:hotconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hotconut_wallet/utils/logger.dart';
import 'package:hotconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:provider/provider.dart';

import 'app.dart';

const methodChannelOS = 'app.hotconut.wallet/os';
// Android Only
const splashBackgroundColorMainnet = Color(0xff1e1e1e);
const splashBackgroundColorRegtest = Color(0xff323232);

void main() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 예외를 완전히 무시하는 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    Logger.error("Flutter Error (무시됨): ${details.exception}");
    Logger.log("Stack trace: ${details.stack}");
  };

  runZonedGuarded(
    () async {
      // This app is designed only to work vertically, so we limit
      // orientations to portrait up and down.
      WidgetsFlutterBinding.ensureInitialized();
      final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
      if (Platform.isAndroid) {
        try {
          const MethodChannel channel = MethodChannel(methodChannelOS);

          final int version = await channel.invokeMethod('getSdkVersion');
          if (version != 26) {
            SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
          }
        } on PlatformException catch (e) {
          Logger.log("Failed to get platform version: '${e.message}'.");
        }
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      }
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      setSystemBarColor(
        Platform.isIOS
            ? CoconutColors.black
            : appFlavor == "mainnet"
            ? splashBackgroundColorMainnet
            : splashBackgroundColorRegtest,
      );
      Provider.debugCheckInvalidValueType = null;
      await SharedPrefsRepository().init();

      String envFile = '$appFlavor.env';
      await dotenv.load(fileName: envFile);

      // Faucet - regtest-only
      HotconutWalletApp.kFaucetHost = dotenv.env[DotenvKeys.apiHost] ?? '';

      // Mainnet, Regtest 등 네트워크 타입 설정
      HotconutWalletApp.kNetworkType = NetworkType.getNetworkType(dotenv.env[DotenvKeys.networkType]!);
      NetworkType.setNetworkType(HotconutWalletApp.kNetworkType);

      // FileLogger 초기화
      await FileLogger.initialize();

      _setupPluralResolvers();

      runApp(const HotconutWalletApp());
    },
    (error, stackTrace) {
      Logger.error(">>>>> runZoneGuarded error: $error");
      Logger.log('>>>>> runZoneGuarded StackTrace: $stackTrace');
    },
  );
}

void _setupPluralResolvers() {
  LocaleSettings.setPluralResolverSync(
    language: 'kr',
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );

  LocaleSettings.setPluralResolverSync(
    language: 'jp',
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other ?? '',
  );

  LocaleSettings.setPluralResolverSync(
    language: 'en',
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 0 && zero != null) return zero;
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );

  LocaleSettings.setPluralResolverSync(
    language: 'es',
    cardinalResolver: (n, {zero, one, two, few, many, other}) {
      if (n == 1 && one != null) return one;
      return other ?? '';
    },
  );
}
