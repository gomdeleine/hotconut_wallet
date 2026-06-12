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
