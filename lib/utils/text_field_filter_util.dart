import 'package:flutter/services.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/utils/locale_util.dart';

String filterNumericInput(String input, {required int decimalPlaces, int integerPlaces = -1}) {
  String allowedCharsInput = input.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  if (input == '00') return '0';
  if (input == '.' || input == ',') return '0.';
  if (RegExp(r'^0[1-9]$').hasMatch(input)) return input.substring(1);

  var splitedInput = allowedCharsInput.split('.');
  if (splitedInput.length == 1 && integerPlaces != -1 && splitedInput[0].length > integerPlaces) {
    /// 정수만 있는 경우 자리수 처리
    return splitedInput[0].substring(0, integerPlaces);
  }

  if (splitedInput.length > 2) {
    return '${splitedInput[0]}.${splitedInput[1]}';
  }

  if (splitedInput.length == 2) {
    /// 소수점까지 있는 경우 자리수 처리
    String integerPart = splitedInput[0];
    String decimalPart = splitedInput[1];

    if (integerPlaces != -1 && splitedInput[0].length > integerPlaces) {
      integerPart = integerPart.substring(0, integerPlaces);
    }
    if (splitedInput[1].length > decimalPlaces) {
      decimalPart = decimalPart.substring(0, decimalPlaces);
    }

    return '$integerPart.$decimalPart';
  }

  return allowedCharsInput;
}

class BtcAmountInputFormatter extends TextInputFormatter {
  static const double maxBtc = 21_000_000;

  final int decimalPlaces;
  final String? localeName;

  const BtcAmountInputFormatter({this.decimalPlaces = 8, this.localeName});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final decimalSeparator = getNumberDecimalSeparator(localeName: localeName);
    final groupingSeparator = getNumberGroupingSeparator(localeName: localeName);
    if (_insertedText(oldValue, newValue).contains(groupingSeparator)) {
      return oldValue;
    }

    final text = newValue.text
        .replaceAll(groupingSeparator, '')
        .replaceAll(decimalSeparator, '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    if (text.isEmpty) return newValue;

    final parts = text.split('.');
    if (parts.length > 2) return oldValue;

    final decimalPart = parts.length > 1 ? parts[1] : '';
    if (decimalPart.length > decimalPlaces) return oldValue;

    final btc = double.tryParse(text);
    if (btc != null && btc > maxBtc) return oldValue;

    final formattedText = _formatBtcText(text, localeName: localeName, decimalSeparator: decimalSeparator);
    final offset = _calculateSelectionOffset(
      originalText: newValue.text,
      formattedText: formattedText,
      baseOffset: newValue.selection.baseOffset,
      decimalSeparator: decimalSeparator,
      groupingSeparator: groupingSeparator,
    );
    return TextEditingValue(text: formattedText, selection: TextSelection.collapsed(offset: offset));
  }
}

class SatoshiAmountInputFormatter extends TextInputFormatter {
  static const int maxSats = 2_100_000_000_000_000;

  final String? localeName;

  const SatoshiAmountInputFormatter({this.localeName});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return newValue;

    final sats = int.tryParse(text);
    if (sats != null && sats > maxSats) return oldValue;

    final groupingSeparator = getNumberGroupingSeparator(localeName: localeName);
    final formattedText = int.parse(text).toThousandsSeparatedString(localeName: localeName);
    final offset = _calculateSelectionOffset(
      originalText: newValue.text,
      formattedText: formattedText,
      baseOffset: newValue.selection.baseOffset,
      groupingSeparator: groupingSeparator,
    );
    return TextEditingValue(text: formattedText, selection: TextSelection.collapsed(offset: offset));
  }
}

String _insertedText(TextEditingValue oldValue, TextEditingValue newValue) {
  if (newValue.text.length <= oldValue.text.length) return '';

  final start = oldValue.selection.baseOffset.clamp(0, oldValue.text.length);
  final end = (start + (newValue.text.length - oldValue.text.length)).clamp(0, newValue.text.length);
  return newValue.text.substring(start, end);
}

String _formatBtcText(String text, {String? localeName, required String decimalSeparator}) {
  if (text == '.' || text == ',') return '0$decimalSeparator';

  final parts = text.replaceAll(',', '.').split('.');
  final integerPart = parts[0].isEmpty ? '0' : parts[0];
  final formattedIntegerPart = int.parse(integerPart).toThousandsSeparatedString(localeName: localeName);

  if (parts.length == 1) {
    return formattedIntegerPart;
  }

  return '$formattedIntegerPart$decimalSeparator${parts[1]}';
}

int _calculateSelectionOffset({
  required String originalText,
  required String formattedText,
  required int baseOffset,
  String decimalSeparator = '.',
  String groupingSeparator = ',',
}) {
  final clampedOffset = baseOffset.clamp(0, originalText.length);

  // .을 입력하면 0.으로 바뀌는 경우(BTC 단위 입력 시 해당) .뒤에 커서를 두기 위해 따로 처리
  if ((originalText.startsWith('.') || originalText.startsWith(',')) &&
      formattedText.startsWith('0$decimalSeparator')) {
    return (clampedOffset + 1).clamp(0, formattedText.length);
  }

  final textBeforeCursor = originalText.substring(0, clampedOffset);
  if (textBeforeCursor.endsWith('.') || textBeforeCursor.endsWith(',')) {
    final decimalOffset = formattedText.indexOf(decimalSeparator) + 1;
    if (decimalOffset > 0) return decimalOffset;
  }

  final meaningfulCharCount = textBeforeCursor.replaceAll(groupingSeparator, '').length;

  var seenMeaningfulChars = 0;
  for (var i = 0; i < formattedText.length; i++) {
    if (formattedText[i] != groupingSeparator) {
      seenMeaningfulChars++;
    }
    if (seenMeaningfulChars >= meaningfulCharCount) {
      return i + 1;
    }
  }

  return formattedText.length;
}
