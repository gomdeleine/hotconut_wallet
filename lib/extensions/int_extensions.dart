import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:intl/intl.dart';

extension IntFormatting on int {
  String toThousandsSeparatedString({String? localeName}) {
    final formatter = NumberFormat.decimalPattern(localeName ?? getNumberFormatLocaleName());
    return formatter.format(this);
  }
}
