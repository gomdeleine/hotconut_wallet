import 'package:hotconut_wallet/config/number_format_config.dart';
import 'package:hotconut_wallet/utils/numeric_input_formatters.dart';

extension IntFormatting on int {
  String toThousandsSeparatedString() {
    return formatIntWithGroupingSeparator(toString(), NumberFormatConfig.instance.groupingSeparator);
  }
}
