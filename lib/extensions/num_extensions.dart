import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';

extension NumberFormatting on num {
  /// 숫자를 로케일에 맞는 표시 형식의 문자열로 변환합니다.
  /// - 천 단위 구분자 적용
  /// - 소수점 구분자를 로케일 설정에 맞게 변환
  /// - trailing zeros 제거 (기본값)
  String toLocaleString({bool trimTrailingZeros = true, int? decimalPlaces}) {
    final decimalSep = NumberFormatConfig.instance.decimalSeparator;
    final groupingSep = NumberFormatConfig.instance.groupingSeparator;

    final str = toString();
    final parts = str.split('.');

    // 정수 부분에 천단위 구분자 적용
    final integerPart = parts[0];
    final formattedInteger = formatIntWithGroupingSeparator(integerPart, groupingSep);

    if (parts.length == 1) {
      return formattedInteger;
    }

    // 소수점 부분 처리
    var decimalPart = parts[1];

    // 소수점 최대 자릿수 제한
    if (decimalPlaces != null && decimalPart.length > decimalPlaces) {
      decimalPart = decimalPart.substring(0, decimalPlaces);
    }

    if (trimTrailingZeros) {
      decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
    }

    if (decimalPart.isEmpty) {
      return formattedInteger;
    }

    return '$formattedInteger$decimalSep$decimalPart';
  }
}
