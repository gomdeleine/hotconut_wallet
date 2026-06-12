import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BtcAmountInputFormatter', () {
    TextEditingValue format(String text, {String localeName = 'en_US'}) {
      final formatter = BtcAmountInputFormatter(localeName: localeName);
      return formatter.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
      );
    }

    test('uses dot as decimal separator for en_US and rejects comma grouping separator', () {
      expect(format('0.1').text, '0.1');

      const oldValue = TextEditingValue(text: '0', selection: TextSelection.collapsed(offset: 1));
      const newValue = TextEditingValue(text: '0,', selection: TextSelection.collapsed(offset: 2));
      const formatter = BtcAmountInputFormatter(localeName: 'en_US');
      expect(formatter.formatEditUpdate(oldValue, newValue), oldValue);
    });

    test('uses comma as decimal separator for de_DE and rejects dot grouping separator', () {
      expect(format('0,1', localeName: 'de_DE').text, '0,1');
      expect(format(',', localeName: 'de_DE').text, '0,');

      const oldValue = TextEditingValue(text: '0', selection: TextSelection.collapsed(offset: 1));
      const newValue = TextEditingValue(text: '0.', selection: TextSelection.collapsed(offset: 2));
      const formatter = BtcAmountInputFormatter(localeName: 'de_DE');
      expect(formatter.formatEditUpdate(oldValue, newValue), oldValue);
    });

    test('rejects multiple decimal separators', () {
      const oldValue = TextEditingValue(text: '0.1', selection: TextSelection.collapsed(offset: 3));
      const newValue = TextEditingValue(text: '0.1.', selection: TextSelection.collapsed(offset: 4));
      const formatter = BtcAmountInputFormatter(localeName: 'en_US');
      expect(formatter.formatEditUpdate(oldValue, newValue), oldValue);
    });
  });

  group('SatoshiAmountInputFormatter', () {
    test('keeps cursor at the end when locale grouping separator is dot', () {
      const formatter = SatoshiAmountInputFormatter(localeName: 'de_DE');
      const oldValue = TextEditingValue(text: '123', selection: TextSelection.collapsed(offset: 3));
      const newValue = TextEditingValue(text: '1234', selection: TextSelection.collapsed(offset: 4));

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1.234');
      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
