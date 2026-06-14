import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('BtcAmountInputFormatter', () {
    TextEditingValue format(String text, {String decimalSeparator = '.', String groupingSeparator = ','}) {
      NumberFormatConfig.instance.update(decimalSeparator == ',' ? 'es' : 'en');
      final formatter = const BtcAmountInputFormatter();
      return formatter.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
      );
    }

    // 실제 키 입력을 한 글자씩 시뮬레이션: 이전 상태에서 다음 상태로 연속 호출
    List<String> typeSequence(List<String> inputs, {String decimalSeparator = '.', String groupingSeparator = ','}) {
      NumberFormatConfig.instance.update(decimalSeparator == ',' ? 'es' : 'en');
      const formatter = BtcAmountInputFormatter();
      var current = const TextEditingValue();
      final results = <String>[];
      for (final input in inputs) {
        // 삭제: '<' 기호로 표시
        TextEditingValue next;
        if (input == '<') {
          if (current.text.isEmpty) {
            next = current;
          } else {
            // 마지막 문자가 groupingSeparator이면 그것도 함께 제거 (실제 키보드 동작과 동일)
            var newText = current.text.substring(0, current.text.length - 1);
            if (newText.isNotEmpty && newText.endsWith(groupingSeparator)) {
              newText = newText.substring(0, newText.length - 1);
            }
            next = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
          }
        } else {
          final newText = current.text + input;
          next = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
        }
        current = formatter.formatEditUpdate(current, next);
        results.add(current.text);
      }
      return results;
    }

    test('NumberFormat.decimalPattern(locale).format(value)', () {
      expect(NumberFormat.decimalPattern('en_US').format(0.1), '0.1');
      expect(NumberFormat.decimalPattern('en_DE').format(0.1), '0.1');
      expect(NumberFormat.decimalPattern('de_DE').format(0.1), '0,1');
      expect(
        NumberFormat.decimalPatternDigits(locale: 'de_DE', decimalDigits: 8).format(1000000.0001),
        '1.000.000,00010000',
      );
      expect(
        NumberFormat.decimalPatternDigits(locale: 'fr_DE', decimalDigits: 8).format(1000000.0001),
        '1\u202F000\u202F000,00010000',
      );
      expect(
        NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: 8).format(1000000.0001),
        '1\u202F000\u202F000,00010000',
      );
    });

    test('입력 시 groupingSeparator 자동 삽입/제거 (en, groupingSep=,)', () {
      final seq = typeSequence(['1', '2', '3', '4', '5', '<', '<']);
      expect(seq, ['1', '12', '123', '1,234', '12,345', '1,234', '123']);
    });

    test('입력 시 groupingSeparator 자동 삽입/제거 (de, groupingSep=.)', () {
      final seq = typeSequence(['1', '2', '3', '4', '5', '<', '<'], decimalSeparator: ',', groupingSeparator: '.');
      expect(seq, ['1', '12', '123', '1.234', '12.345', '1.234', '123']);
    });

    test('소수점 입력 후 추가 입력/삭제 (en)', () {
      final seq = typeSequence(['1', '0', '0', '0', '.', '5', '<']);
      expect(seq, ['1', '10', '100', '1,000', '1,000.', '1,000.5', '1,000.']);
    });

    test('소수점 입력 후 추가 입력/삭제 (de, decimalSep=,)', () {
      final seq = typeSequence(['1', '0', '0', '0', ',', '5', '<'], decimalSeparator: ',', groupingSeparator: '.');
      expect(seq, ['1', '10', '100', '1.000', '1.000,', '1.000,5', '1.000,']);
    });

    test('CASE1 연속입력: decimalSep=dot, 쉼표로 소수점 입력 후 숫자 추가/삭제 (en)', () {
      // 사용자가 1000,5 입력 (쉼표를 소수점으로 사용)
      final seq = typeSequence(['1', '0', '0', '0', ',', '5', '<', '<']);
      expect(seq, ['1', '10', '100', '1,000', '1,000.', '1,000.5', '1,000.', '1,000']);
    });

    test('CASE1 연속입력: decimalSep=dot, 12345678,222 입력 (en)', () {
      // maxBtc=21,000,000 이내 값 사용
      final seq = typeSequence(['1', '2', '3', '4', '5', '6', '7', '8', ',', '2', '2', '2']);
      expect(seq, [
        '1',
        '12',
        '123',
        '1,234',
        '12,345',
        '123,456',
        '1,234,567',
        '12,345,678',
        '12,345,678.',
        '12,345,678.2',
        '12,345,678.22',
        '12,345,678.222',
      ]);
    });

    test('CASE1 연속입력: decimalSep=dot, 쉼표만 단독 입력 후 숫자 추가/삭제 (en)', () {
      // 사용자가 ,5 입력 (쉼표를 소수점으로 사용)
      final seq = typeSequence([',', '5', '<', '<', '.', '.', ',']);
      expect(seq, ['0.', '0.5', '0.', '0', '0.', '0.', '0.']);
    });

    test('CASE2 연속입력: decimalSep=comma, 마침표만 단독 입력 후 숫자 추가/삭제 (de)', () {
      // 사용자가 .5 입력 (마침표를 소수점으로 사용)
      final seq = typeSequence(['.', '5', '<', '<', ',', ',', '.'], decimalSeparator: ',', groupingSeparator: '.');
      expect(seq, ['0,', '0,5', '0,', '0', '0,', '0,', '0,']);
    });

    test('CASE2 연속입력: decimalSep=comma, 마침표로 소수점 입력 후 숫자 추가/삭제 (de)', () {
      // 사용자가 1000.5 입력 (마침표를 소수점으로 사용)
      final seq = typeSequence(['1', '0', '0', '0', '.', '5', '<', '<'], decimalSeparator: ',', groupingSeparator: '.');
      expect(seq, ['1', '10', '100', '1.000', '1.000,', '1.000,5', '1.000,', '1.000']);
    });

    test('CASE1: decimalSep=dot, 쉼표 입력 시 소수점 없으면 마침표로 변환', () {
      NumberFormatConfig.instance.update('en');
      // 소수점 없는 상태에서 쉼표 → 마침표 변환
      expect(format(',').text, '0.');

      const formatter = BtcAmountInputFormatter();
      // '1,000' 상태에서 쉼표 추가 → 소수점으로 변환 (소수점 없으므로)
      const before = TextEditingValue(text: '1,000', selection: TextSelection.collapsed(offset: 5));
      const adding = TextEditingValue(text: '1,000,', selection: TextSelection.collapsed(offset: 6));
      expect(formatter.formatEditUpdate(before, adding).text, '1,000.');

      // '1,000.' 상태에서 쉼표 추가 → 거부 (소수점 이미 있음)
      const withDecimal = TextEditingValue(text: '1,000.', selection: TextSelection.collapsed(offset: 6));
      const addingAgain = TextEditingValue(text: '1,000.,', selection: TextSelection.collapsed(offset: 7));
      expect(formatter.formatEditUpdate(withDecimal, addingAgain), withDecimal);
    });

    test('CASE2: decimalSep=comma, 마침표 입력 시 소수점 없으면 쉼표로 변환', () {
      NumberFormatConfig.instance.update('es');
      // 소수점 없는 상태에서 마침표 → 쉼표 변환
      expect(format('.', decimalSeparator: ',', groupingSeparator: '.').text, '0,');

      const formatter = BtcAmountInputFormatter();
      // '1.000' 상태에서 마침표 추가 → 소수점으로 변환 (소수점 없으므로)
      const before = TextEditingValue(text: '1.000', selection: TextSelection.collapsed(offset: 5));
      const adding = TextEditingValue(text: '1.000.', selection: TextSelection.collapsed(offset: 6));
      expect(formatter.formatEditUpdate(before, adding).text, '1.000,');

      // '1.000,' 상태에서 마침표 추가 → 거부 (소수점 이미 있음)
      const withDecimal = TextEditingValue(text: '1.000,', selection: TextSelection.collapsed(offset: 6));
      const addingAgain = TextEditingValue(text: '1.000,.', selection: TextSelection.collapsed(offset: 7));
      expect(formatter.formatEditUpdate(withDecimal, addingAgain), withDecimal);
    });

    test('rejects multiple decimal separators', () {
      NumberFormatConfig.instance.update('en');
      const oldValue = TextEditingValue(text: '0.1', selection: TextSelection.collapsed(offset: 3));
      const newValue = TextEditingValue(text: '0.1.', selection: TextSelection.collapsed(offset: 4));
      const formatter = BtcAmountInputFormatter();
      expect(formatter.formatEditUpdate(oldValue, newValue), oldValue);
    });
  });

  group('SatoshiAmountInputFormatter', () {
    test('keeps cursor at the end when locale grouping separator is dot', () {
      NumberFormatConfig.instance.update('es');
      const formatter = SatoshiAmountInputFormatter();
      const oldValue = TextEditingValue(text: '123', selection: TextSelection.collapsed(offset: 3));
      const newValue = TextEditingValue(text: '1234', selection: TextSelection.collapsed(offset: 4));

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1.234');
      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
