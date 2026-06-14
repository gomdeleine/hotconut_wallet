import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';

extension IntFormatting on int {
  String toThousandsSeparatedString() {
    return formatIntWithGroupingSeparator(this, NumberFormatConfig.instance.groupingSeparator);
  }
}
