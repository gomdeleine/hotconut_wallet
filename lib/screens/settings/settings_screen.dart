import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:hotconut_wallet/enums/fiat_enums.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/preferences/preference_provider.dart';
import 'package:hotconut_wallet/providers/view_model/settings/settings_view_model.dart';
import 'package:hotconut_wallet/providers/wallet_provider.dart';
import 'package:hotconut_wallet/repository/realm/realm_manager.dart';
import 'package:hotconut_wallet/screens/common/pin_check_screen.dart';
import 'package:hotconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:hotconut_wallet/screens/settings/realm_debug_screen.dart';
import 'package:hotconut_wallet/screens/settings/unit_bottom_sheet.dart';
import 'package:hotconut_wallet/screens/settings/language_bottom_sheet.dart';
import 'package:hotconut_wallet/screens/settings/fiat_bottom_sheet.dart';
import 'package:hotconut_wallet/utils/hot_wallet_util.dart';
import 'package:hotconut_wallet/utils/vibration_util.dart';
import 'package:hotconut_wallet/widgets/button/button_group.dart';
import 'package:hotconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:hotconut_wallet/widgets/dialog.dart';
import 'package:hotconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hotconut_wallet/widgets/button/single_button.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreen();
}

class _SettingsScreen extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<AuthProvider, PreferenceProvider, SettingsViewModel>(
      create:
          (_) => SettingsViewModel(
            Provider.of<AuthProvider>(context, listen: false),
            Provider.of<PreferenceProvider>(context, listen: false),
          ),
      update: (_, authProvider, preferenceProvider, settingsViewModel) {
        return SettingsViewModel(authProvider, preferenceProvider);
      },
      child: Consumer<SettingsViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(title: t.settings, context: context, isBottom: true),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 보안
                  _category(t.security),
                  ButtonGroup(
                    buttons: [
                      SingleButton(
                        title: t.settings_screen.set_password,
                        rightElement: _buildSwitch(
                          isOn: viewModel.isSetPin,
                          onChanged: (isOn) async {
                            if (isOn) {
                              _showPinSettingScreen(useBiometrics: true);
                              return;
                            }

                            if (hasHotWallet(context.read<WalletProvider>())) {
                              await showInfoDialog(
                                context,
                                context.read<PreferenceProvider>().language,
                                t.hot_wallet.pin_disable_blocked_title,
                                t.hot_wallet.pin_disable_blocked_description,
                              );
                              return;
                            }

                            final authProvider = viewModel.authProvider;
                            if (await authProvider.isBiometricsAuthValid()) {
                              viewModel.deletePin();
                              return;
                            }

                            if (await _isPinCheckValid()) {
                              viewModel.deletePin();
                            }
                          },
                        ),
                      ),
                      if (viewModel.canCheckBiometrics && viewModel.isSetPin)
                        SingleButton(
                          title: t.settings_screen.use_biometric,
                          rightElement: _buildSwitch(
                            isOn: viewModel.isSetBiometrics,
                            onChanged: (isOn) async {
                              if (isOn) {
                                final pin = await _getPinFromCheck();
                                if (pin == null) return;

                                final authProvider = viewModel.authProvider;
                                await authProvider.enableHotWalletBiometricFastPath(pin);
                                await authProvider.authenticateWithBiometrics(isSave: true);
                              } else {
                                viewModel.saveIsSetBiometrics(false);
                              }
                            },
                          ),
                        ),
                      if (viewModel.isSetPin)
                        SingleButton(
                          title: t.settings_screen.change_password,
                          onPressed: () async {
                            final authProvider = viewModel.authProvider;
                            if (await authProvider.isBiometricsAuthValid()) {
                              _showPinSettingScreen(useBiometrics: false);
                              return;
                            }

                            if (await _isPinCheckValid()) {
                              _showPinSettingScreen(useBiometrics: false);
                            }
                          },
                        ),
                    ],
                  ),

                  // if (context.read<WalletProvider>().walletItemList.isNotEmpty) ...[
                  //   CoconutLayout.spacing_200h,
                  //   MultiButton(
                  //     children: [
                  //       SingleButton(
                  //         title: t.settings_screen.hide_balance,
                  //         rightElement: CupertinoSwitch(
                  //             value: viewModel.isBalanceHidden,
                  //             activeColor: CoconutColors.gray100,
                  //             trackColor: CoconutColors.gray600,
                  //             thumbColor: CoconutColors.gray800,
                  //             onChanged: (value) {
                  //               viewModel.changeIsBalanceHidden(value);
                  //             }),
                  //       ),
                  //       if (viewModel.isBalanceHidden)
                  //         SingleButton(
                  //           title: t.settings_screen.fake_balance.fake_balance_setting,
                  //           onPressed: () async {
                  //             CommonBottomSheets.showBottomSheet_50(
                  //                 context: context, child: const FakeBalanceBottomSheet());
                  //           },
                  //         ),
                  //     ],
                  //   ),
                  // ],
                  CoconutLayout.spacing_400h,

                  // 단위
                  _category(t.unit),
                  ButtonGroup(
                    buttons: [
                      Selector<PreferenceProvider, BitcoinUnit>(
                        selector: (_, viewModel) => viewModel.currentUnit,
                        builder: (context, currentUnit, child) {
                          return _buildAnimatedButton(
                            title: t.bitcoin,
                            subtitle: currentUnit.symbol,
                            onPressed: () async {
                              CommonBottomSheets.showCustomHeightBottomSheet(
                                context: context,
                                heightRatio: 0.5,
                                child: const UnitBottomSheet(),
                              );
                            },
                          );
                        },
                      ),
                      Selector<PreferenceProvider, String>(
                        selector: (_, provider) => provider.selectedFiat.code,
                        builder: (context, fiatCode, child) {
                          String fiatDisplayName;
                          switch (fiatCode) {
                            case 'KRW':
                              fiatDisplayName = FiatCode.KRW.code;
                              break;
                            case 'JPY':
                              fiatDisplayName = FiatCode.JPY.code;
                              break;
                            case 'USD':
                            default:
                              fiatDisplayName = FiatCode.USD.code;
                              break;
                          }
                          return _buildAnimatedButton(
                            title: t.settings_screen.fiat,
                            subtitle: fiatDisplayName,
                            onPressed: () async {
                              CommonBottomSheets.showCustomHeightBottomSheet(
                                context: context,
                                heightRatio: 0.5,
                                child: const FiatBottomSheet(),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  CoconutLayout.spacing_400h,

                  // 일반
                  _category(t.general),
                  ButtonGroup(
                    buttons: [
                      Selector<PreferenceProvider, String>(
                        selector: (_, provider) => provider.language,
                        builder: (context, language, child) {
                          return _buildAnimatedButton(
                            title: t.settings_screen.language,
                            subtitle: _getCurrentLanguageDisplayName(language),
                            onPressed: () async {
                              CommonBottomSheets.showCustomHeightBottomSheet(
                                context: context,
                                heightRatio: 0.5,
                                child: LanguageBottomSheet(),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  CoconutLayout.spacing_400h,

                  // 네트워크
                  _category(t.network),
                  // mainnet인 경우만 블록 익스플로러 표시
                  NetworkType.currentNetworkType == NetworkType.mainnet
                      ? ButtonGroup(
                        buttons: [
                          _buildAnimatedButton(
                            title: t.electrum_server,
                            onPressed: () async {
                              Navigator.pushNamed(context, '/electrum-server');
                            },
                          ),
                          _buildAnimatedButton(
                            title: t.block_explorer,
                            onPressed: () async {
                              Navigator.pushNamed(context, '/block-explorer');
                            },
                          ),
                        ],
                      )
                      : _buildAnimatedButton(
                        title: t.electrum_server,
                        onPressed: () async {
                          Navigator.pushNamed(context, '/electrum-server');
                        },
                      ),

                  CoconutLayout.spacing_400h,

                  // 도구
                  _category(t.tool),
                  ButtonGroup(
                    buttons: [
                      SingleButton(
                        title: t.settings_screen.utxo_manual_selection,
                        subtitle: t.settings_screen.utxo_manual_selection_description,
                        isVerticalSubtitle: true,
                        rightElement: _buildSwitch(
                          isOn: viewModel.isManualUtxoSelectionMode,
                          onChanged: (isOn) async {
                            viewModel.setManualUtxoSelectionMode(isOn);
                            vibrateExtraLight();
                          },
                        ),
                      ),
                      _buildAnimatedButton(
                        title: t.log_viewer,
                        onPressed: () {
                          Navigator.pushNamed(context, '/log-viewer');
                        },
                      ),
                    ],
                  ),

                  // 개발자 모드에서만 표시되는 디버그 섹션
                  if (kDebugMode) ...[
                    CoconutLayout.spacing_400h,
                    _category('개발자 도구'),
                    _buildAnimatedButton(
                      title: 'Realm 디버그용 뷰어',
                      onPressed: () {
                        final realmManager = Provider.of<RealmManager>(context, listen: false);
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (context) => RealmDebugScreen(realmManager: realmManager)));
                      },
                    ),
                  ],

                  CoconutLayout.spacing_400h,

                  // 앱 정보 보기
                  _category(t.app_info),
                  _buildAnimatedButton(
                    title: t.view_app_info,
                    onPressed: () => Navigator.pushNamed(context, '/app-info'),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitch({required bool isOn, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CoconutSwitch(
        isOn: isOn,
        activeColor: CoconutColors.gray100,
        trackColor: CoconutColors.gray600,
        thumbColor: CoconutColors.gray800,
        onChanged: onChanged,
        scale: 0.75,
      ),
    );
  }

  Widget _category(String label) => Container(
    padding: const EdgeInsets.fromLTRB(8, 20, 0, 12),
    child: Text(label, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
  );

  Widget _buildAnimatedButton({required String title, required VoidCallback onPressed, String? subtitle}) {
    return SingleButton(
      enableShrinkAnim: true,
      animationEndValue: 0.97,
      title: title,
      subtitle: subtitle,
      onPressed: onPressed,
    );
  }

  Future<void> _showPinSettingScreen({required bool useBiometrics}) async {
    final success = await CommonBottomSheets.showCustomHeightBottomSheet<bool>(
      context: context,
      heightRatio: 0.9,
      child: CustomLoadingOverlay(child: PinSettingScreen(useBiometrics: useBiometrics)),
    );
    if (success == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _isPinCheckValid() async {
    return (await CommonBottomSheets.showCustomHeightBottomSheet(
          context: context,
          heightRatio: 0.9,
          child: const CustomLoadingOverlay(child: PinCheckScreen()),
        ) ==
        true);
  }

  Future<String?> _getPinFromCheck() async {
    final result = await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: const CustomLoadingOverlay(child: PinCheckScreen(returnPinOnSuccess: true)),
    );
    return result is String ? result : null;
  }

  String _getCurrentLanguageDisplayName(String language) {
    switch (language) {
      case 'kr':
        return t.settings_screen.locales.korean;
      case 'jp':
        return t.settings_screen.locales.japanese;
      case 'es':
        return t.settings_screen.locales.spanish;
      case 'en':
      default:
        return t.settings_screen.locales.english;
    }
  }
}
