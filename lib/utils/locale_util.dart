import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:intl/number_symbols.dart';

String getNumberFormatLocaleName() {
  final locales = PlatformDispatcher.instance.locales;
  final locale = locales.isNotEmpty ? locales.first : PlatformDispatcher.instance.locale;

  return Intl.canonicalizedLocale(locale.toLanguageTag());
}

NumberSymbols getNumberFormatSymbols({String? localeName}) {
  return NumberFormat.decimalPattern(localeName ?? getNumberFormatLocaleName()).symbols;
}

String getNumberDecimalSeparator({String? localeName}) {
  return getNumberFormatSymbols(localeName: localeName).DECIMAL_SEP;
}

String getNumberGroupingSeparator({String? localeName}) {
  return getNumberFormatSymbols(localeName: localeName).GROUP_SEP;
}

String normalizeNumberTextForParsing(String text, {String? localeName}) {
  final groupingSeparator = getNumberGroupingSeparator(localeName: localeName);
  final decimalSeparator = getNumberDecimalSeparator(localeName: localeName);

  return text.trim().replaceAll(groupingSeparator, '').replaceAll(decimalSeparator, '.');
}

String normalizeDecimalNumberTextForParsing(String text, {String? localeName}) {
  final groupingSeparator = getNumberGroupingSeparator(localeName: localeName);
  final decimalSeparator = getNumberDecimalSeparator(localeName: localeName);
  final compactText = text.trim().replaceAll(RegExp(r'\s+'), '');
  if (compactText.isEmpty) return compactText;

  final lastDotIndex = compactText.lastIndexOf('.');
  final lastCommaIndex = compactText.lastIndexOf(',');
  if (lastDotIndex != -1 && lastCommaIndex != -1) {
    final inferredDecimalSeparator = lastDotIndex > lastCommaIndex ? '.' : ',';
    final inferredGroupingSeparator = inferredDecimalSeparator == '.' ? ',' : '.';
    return compactText.replaceAll(inferredGroupingSeparator, '').replaceAll(inferredDecimalSeparator, '.');
  }

  if (decimalSeparator == ',' && compactText.contains(',')) {
    return normalizeNumberTextForParsing(compactText, localeName: localeName);
  }

  if (decimalSeparator == '.' && compactText.contains('.')) {
    return normalizeNumberTextForParsing(compactText, localeName: localeName);
  }

  if (compactText.contains(',')) {
    return _normalizeSingleSeparatorDecimalText(
      compactText,
      separator: ',',
      groupingSeparator: groupingSeparator,
      localeName: localeName,
    );
  }

  if (compactText.contains('.')) {
    return _normalizeSingleSeparatorDecimalText(
      compactText,
      separator: '.',
      groupingSeparator: groupingSeparator,
      localeName: localeName,
    );
  }

  return compactText;
}

String _normalizeSingleSeparatorDecimalText(
  String text, {
  required String separator,
  required String groupingSeparator,
  String? localeName,
}) {
  final parts = text.split(separator);
  if (parts.length != 2) {
    return normalizeNumberTextForParsing(text, localeName: localeName);
  }

  final integerPart = parts.first;
  final fractionalPart = parts.last;
  final shouldTreatAsDecimal = separator != groupingSeparator || integerPart == '0' || fractionalPart.length != 3;
  if (!shouldTreatAsDecimal) {
    return normalizeNumberTextForParsing(text, localeName: localeName);
  }

  return '${integerPart.isEmpty ? '0' : integerPart}.$fractionalPart';
}

/// 시스템 언어를 감지하여 적절한 언어 코드를 반환합니다.
String getSystemLanguageCode() {
  final Locale systemLocale = PlatformDispatcher.instance.locale;
  final String languageCode = systemLocale.languageCode.toLowerCase();

  switch (languageCode) {
    case 'ko':
      return 'kr';
    case 'ja':
    case 'jp':
      return 'jp';
    case 'es':
      return 'es';
    default:
      return 'en';
  }
}

/// 시스템 언어가 한국어인지 확인합니다.
bool isSystemLanguageKorean() {
  return getSystemLanguageCode() == 'kr';
}

/// 시스템 언어가 일본어인지 확인합니다.
bool isSystemLanguageJapanese() {
  return getSystemLanguageCode() == 'jp';
}

/// 앱 언어 코드를 intl 로케일 코드로 매핑
const Map<String, String> _appLanguageToIntlLocale = {'kr': 'ko', 'en': 'en', 'jp': 'ja', 'es': 'es'};

/// 앱 설정 언어 기반 소수점 구분자 반환 (기본값: '.')
String getDecimalSeparatorForAppLanguage(String appLanguageCode) {
  final intlLocale = _appLanguageToIntlLocale[appLanguageCode] ?? 'en';
  return getNumberDecimalSeparator(localeName: intlLocale);
}

/// 앱 설정 언어 기반 천 단위 구분자 반환 (기본값: ',')
String getGroupingSeparatorForAppLanguage(String appLanguageCode) {
  final intlLocale = _appLanguageToIntlLocale[appLanguageCode] ?? 'en';
  return getNumberGroupingSeparator(localeName: intlLocale);
}

/// 앱 설정 언어 기반 천 단위/소수점 구분자를 사용하여 BigInt 포맷팅
/// 예: value=BigInt.parse('10000000001'), decimalPlaces=8 → '1,000.00000001' (trailing zeros 제거)
String formatBigIntWithAppLanguageLocale(BigInt value, int decimalPlaces, String appLanguageCode) {
  final intlLocale = _appLanguageToIntlLocale[appLanguageCode] ?? 'en';
  final decimalSep = getNumberDecimalSeparator(localeName: intlLocale);
  final groupSep = getNumberGroupingSeparator(localeName: intlLocale);

  // 음수 처리
  final isNegative = value.isNegative;
  final absValue = value.abs().toString().padLeft(decimalPlaces + 1, '0');

  // 정수부/소수부 분리
  final integerLen = absValue.length - decimalPlaces;
  final integerPart = absValue.substring(0, integerLen);
  var fractionalPart = absValue.substring(integerLen).replaceAll(RegExp(r'0+$'), '');

  // 천 단위 구분자 추가
  final formattedInteger = _addGroupingSeparators(integerPart, groupSep);

  // 결과 조합
  final result = fractionalPart.isEmpty ? formattedInteger : '$formattedInteger$decimalSep$fractionalPart';

  return isNegative ? '-$result' : result;
}

/// 문자열에 천 단위 구분자 추가
String _addGroupingSeparators(String integerPart, String groupSep) {
  if (integerPart.length <= 3) return integerPart;

  final buffer = StringBuffer();
  for (var i = 0; i < integerPart.length; i++) {
    if (i > 0 && (integerPart.length - i) % 3 == 0) {
      buffer.write(groupSep);
    }
    buffer.write(integerPart[i]);
  }
  return buffer.toString();
}
