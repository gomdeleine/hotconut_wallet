import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class RoleDescriptionCard extends StatelessWidget {
  final String description;
  final Color themeColor;
  final Color backgroundColor;
  final RegExp? highlightPattern;

  const RoleDescriptionCard({
    super.key,
    required this.description,
    required this.themeColor,
    required this.backgroundColor,
    this.highlightPattern,
  });

  @override
  Widget build(BuildContext context) {
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
          children: _buildTextSpans(description, highlightPattern, themeColor),
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, RegExp? pattern, Color textColor) {
    final List<TextSpan> spans = [];
    if (pattern == null) {
      spans.add(TextSpan(text: text));
      return spans;
    }

    final matches = pattern.allMatches(text);
    if (matches.isEmpty) {
      spans.add(TextSpan(text: text));
      return spans;
    }

    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: CoconutTypography.body3_12_Bold.setColor(textColor)));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }
}

/// 역할 별 스타일 및 설정 정의
class RoleDescriptionTheme {
  final Color themeColor;
  final Color backgroundColor;
  final RegExp highlightPattern;

  const RoleDescriptionTheme({required this.themeColor, required this.backgroundColor, required this.highlightPattern});

  static RoleDescriptionTheme get cosigner => RoleDescriptionTheme(
    themeColor: CoconutColors.periwinkle,
    backgroundColor: CoconutColors.periwinkle.withValues(alpha: 0.2),
    highlightPattern: RegExp(r'共同署名者|공동 서명자|cosigner', caseSensitive: false),
  );

  static RoleDescriptionTheme get heir => RoleDescriptionTheme(
    themeColor: CoconutColors.lightSky,
    backgroundColor: CoconutColors.lightSky.withValues(alpha: 0.2),
    highlightPattern: RegExp(r'상속자|相続人|heir', caseSensitive: false),
  );
}
