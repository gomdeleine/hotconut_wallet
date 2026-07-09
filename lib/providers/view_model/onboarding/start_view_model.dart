import 'package:hotconut_wallet/app.dart';
import 'package:hotconut_wallet/providers/auth_provider.dart';
import 'package:hotconut_wallet/providers/visibility_provider.dart';
import 'package:flutter/material.dart';

class StartViewModel extends ChangeNotifier {
  late final VisibilityProvider _visibilityProvider;
  late final AuthProvider _authProvider;

  bool _isLoading = true;

  StartViewModel(this._visibilityProvider, this._authProvider) {
    _initialize();
  }

  bool get hasLaunchedBefore => _visibilityProvider.hasLaunchedBefore;
  bool get isLoading => _isLoading;
  bool get isSetPin => _authProvider.isSetPin;
  int get walletCount => _visibilityProvider.walletCount;

  Future<AppEntryFlow> determineStartScreen() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!hasLaunchedBefore) {
      await _visibilityProvider.setHasLaunchedBefore();
    }

    debugPrint(
      'walletCount = ${_visibilityProvider.walletCount} isAuthEnabled = ${_authProvider.isAuthEnabled} isBiometricsAuthEnabled = ${_authProvider.isBiometricsAuthEnabled}',
    );
    if (_visibilityProvider.walletCount == 0 || !_authProvider.isAuthEnabled) {
      return AppEntryFlow.main;
    }

    if (await _authProvider.isBiometricsAuthValid()) {
      return AppEntryFlow.main;
    }
    return AppEntryFlow.pinCheck;
  }

  Future<void> _initialize() async {
    _isLoading = false;
    notifyListeners();
  }
}
