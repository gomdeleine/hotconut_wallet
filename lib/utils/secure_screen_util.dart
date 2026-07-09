import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hotconut_wallet/main.dart';
import 'package:hotconut_wallet/utils/logger.dart';

/// 민감 화면(니모닉/서명)에서 스크린샷·화면 녹화·최근 앱 미리보기를 차단한다.
///
/// Android는 `FLAG_SECURE`를 설정한다. iOS는 직접 대응이 없어 no-op이다.
class SecureScreenUtil {
  static const MethodChannel _channel = MethodChannel(methodChannelOS);

  static Future<void> enable() => _setSecureFlag(true);

  static Future<void> disable() => _setSecureFlag(false);

  static Future<void> _setSecureFlag(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setSecureFlag', {'enabled': enabled});
    } catch (e) {
      Logger.log('SecureScreenUtil.setSecureFlag failed: $e');
    }
  }
}

/// StatefulWidget State에 섞어 쓰면 화면 진입 시 보안 플래그를 켜고 이탈 시 끈다.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    SecureScreenUtil.enable();
  }

  @override
  void dispose() {
    SecureScreenUtil.disable();
    super.dispose();
  }
}
