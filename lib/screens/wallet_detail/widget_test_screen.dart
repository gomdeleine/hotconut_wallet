//TODO: 이 파일은 테스트용으로 만든 화면입니다. 추후 제거 필요

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/card/role_description_card.dart';
import 'package:flutter/material.dart';

class WidgetTestScreen extends StatelessWidget {
  const WidgetTestScreen({super.key});

  static const List<String> _testCases = [
    '나는 이 지갑의 공동 서명자예요.\n다른 공동 서명자와 함께 서명해야 자산을 사용할 수 있어요.',
    '나는 이 지갑의 상속자예요.\n정해진 시점이 지나면 자산을 사용할 수 있어요.',
    'You are a cosigner for this wallet.\nYou must sign with other cosigners to use assets.',
    'You are the heir to this wallet.\nYou can use assets after a set point in time.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(title: 'Widget Test', context: context),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _testCases.length,
        separatorBuilder: (context, index) => CoconutLayout.spacing_200h,
        itemBuilder: (context, index) {
          final bool isParent = index % 2 == 0;
          final roleTheme = isParent ? RoleDescriptionTheme.cosigner : RoleDescriptionTheme.heir;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Case ${index + 1} (${isParent ? 'Parent' : 'Child'})',
                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
              ),
              CoconutLayout.spacing_100h,
              RoleDescriptionCard(
                description: _testCases[index],
                themeColor: roleTheme.themeColor,
                backgroundColor: roleTheme.backgroundColor,
                highlightPattern: roleTheme.highlightPattern,
              ),
            ],
          );
        },
      ),
    );
  }
}
