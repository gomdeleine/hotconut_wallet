import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';

void main() {
  group('IntFormatting Extension Tests', () {
    test('toThousandsSeparatedString formats zero correctly', () {
      expect(0.toThousandsSeparatedString(localeName: 'en_US'), '0');
    });

    test('toThousandsSeparatedString formats small numbers correctly', () {
      expect(1.toThousandsSeparatedString(localeName: 'en_US'), '1');
      expect(999.toThousandsSeparatedString(localeName: 'en_US'), '999');
    });

    test('toThousandsSeparatedString formats thousands correctly', () {
      expect(1000.toThousandsSeparatedString(localeName: 'en_US'), '1,000');
      expect(10000.toThousandsSeparatedString(localeName: 'en_US'), '10,000');
      expect(100000.toThousandsSeparatedString(localeName: 'en_US'), '100,000');
    });

    test('toThousandsSeparatedString formats millions correctly', () {
      expect(1000000.toThousandsSeparatedString(localeName: 'en_US'), '1,000,000');
      expect(1234567.toThousandsSeparatedString(localeName: 'en_US'), '1,234,567');
    });

    test('toThousandsSeparatedString formats by locale', () {
      expect(1234567.toThousandsSeparatedString(localeName: 'de_DE'), '1.234.567');
    });

    test('toThousandsSeparatedString formats negative numbers correctly', () {
      expect((-1000).toThousandsSeparatedString(localeName: 'en_US'), '-1,000');
      expect((-1000000).toThousandsSeparatedString(localeName: 'en_US'), '-1,000,000');
    });

    test('toThousandsSeparatedString formats max/min int values correctly', () {
      expect(2147483647.toThousandsSeparatedString(localeName: 'en_US'), '2,147,483,647'); // max 32-bit int
      expect((-2147483648).toThousandsSeparatedString(localeName: 'en_US'), '-2,147,483,648'); // min 32-bit int
    });
  });
}
