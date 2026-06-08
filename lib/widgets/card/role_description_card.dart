import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class RoleDescriptionCard extends StatelessWidget {
  final String text;
  final bool isParent;

  const RoleDescriptionCard({super.key, required this.text, this.isParent = true});

  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(r'共同署名者|공동 서명자|cosigner|상속자|相続人|heir', caseSensitive: false);

    final Color backgroundColor =
        isParent ? CoconutColors.periwinkle.withValues(alpha: 0.2) : CoconutColors.lightSky.withValues(alpha: 0.2);
    final Color themeColor = isParent ? CoconutColors.periwinkle : CoconutColors.lightSky;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor),
      ),
      child: RichText(
        text: TextSpan(
          style: CoconutTypography.body3_12.setColor(themeColor),
          children: _buildTextSpans(text, pattern, themeColor),
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, RegExp pattern, Color textColor) {
    final List<TextSpan> spans = [];
    final match = pattern.firstMatch(text);

    if (match != null) {
      spans.add(TextSpan(text: text.substring(0, match.start)));
      spans.add(TextSpan(text: match.group(0), style: CoconutTypography.body3_12_Bold.setColor(textColor)));
      spans.add(TextSpan(text: text.substring(match.end)));
    } else {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}
