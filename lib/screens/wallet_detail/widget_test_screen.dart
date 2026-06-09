//TODO: 이 파일은 테스트용으로 만든 화면입니다. 추후 제거 필요

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/card/role_description_card.dart';
import 'package:coconut_wallet/widgets/card/taproot_participant_card.dart';
import 'package:coconut_wallet/widgets/card/taproot_setup_summary_card.dart';
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
    final List<TaprootParticipantCard> summaryItems = [
      const TaprootParticipantCard(
        role: TaprootParticipantRole.parent,
        isMine: true,
        walletName: 'My Hot Wallet',
        mfp: 'F75F7AB5',
        derivationPath: "m/86'/1'/0'/0/0",
      ),
      const TaprootParticipantCard(
        role: TaprootParticipantRole.parent,
        isMine: false,
        walletName: 'Cosigner A',
        mfp: 'A1B2C3D4',
        derivationPath: "m/86'/1'/0'/0/1",
      ),
      const TaprootParticipantCard(
        role: TaprootParticipantRole.child,
        isMine: false,
        walletName: 'Heir 1',
        mfp: 'E5F6G7H8',
        derivationPath: "m/86'/1'/0'/0/2",
        locktime: 1735689600,
      ),
    ];

    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(title: 'Widget Test', context: context),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('Existing Role Description Cards'),
          ...List.generate(_testCases.length, (index) {
            final bool isParent = index % 2 == 0;
            final roleTheme = isParent ? RoleDescriptionTheme.cosigner : RoleDescriptionTheme.heir;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Old Case ${index + 1} (${isParent ? 'Parent' : 'Child'})',
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
              ),
            );
          }),

          const Divider(color: CoconutColors.gray800, height: 40),
          _buildSectionTitle('New Taproot Participant Cards'),
          CoconutLayout.spacing_200h,

          // 1. 나 (isMine = true)
          const TaprootParticipantCard(
            role: TaprootParticipantRole.parent,
            isMine: true,
            hasBackgroundColor: true,
            walletName: 'My Hot Wallet',
            mfp: 'F75F7AB5',
            derivationPath: "m/86'/1'/0'/0/0",
          ),
          CoconutLayout.spacing_200h,

          // 2. 공동 서명자 (isMine = false, hasSingleParent = false)
          const TaprootParticipantCard(
            role: TaprootParticipantRole.parent,
            isMine: false,
            walletName: 'Cosigner A',
            mfp: 'A1B2C3D4',
            derivationPath: "m/86'/1'/0'/0/1",
          ),
          CoconutLayout.spacing_200h,

          // 3. 조건부 서명자 (role = child)
          const TaprootParticipantCard(
            role: TaprootParticipantRole.child,
            isMine: false,
            walletName: 'Heir 1',
            mfp: 'E5F6G7H8',
            derivationPath: "m/86'/1'/0'/0/2",
          ),
          CoconutLayout.spacing_200h,

          // 4. 서명자 (hasSingleParent = true)
          const TaprootParticipantCard(
            role: TaprootParticipantRole.parent,
            isMine: false,
            hasSingleParent: true,
            walletName: 'Single Signer',
            mfp: 'I9J0K1L2',
            derivationPath: "m/86'/1'/0'/0/3",
          ),
          CoconutLayout.spacing_200h,

          // 5. 일시 이후 (locktime 설정)
          const TaprootParticipantCard(
            role: TaprootParticipantRole.child,
            isMine: false,
            hasBackgroundColor: true,
            mfp: 'M3N4O5P6',
            derivationPath: "m/86'/1'/0'/0/4",
            locktime: 1735689600, // 2025.01.01 00:00 (Unix timestamp)
          ),
          CoconutLayout.spacing_400h,

          const Divider(color: CoconutColors.gray800, height: 40),
          _buildSectionTitle('Taproot Setup Summary Card - Card Type'),
          CoconutLayout.spacing_200h,
          TaprootSetupSummaryCard(
            itemList: summaryItems,
            taprootSetupSummaryCardType: TaprootSetupSummaryCardType.card,
          ),
          CoconutLayout.spacing_400h,

          const Divider(color: CoconutColors.gray800, height: 40),
          _buildSectionTitle('Taproot Setup Summary Card - Tree Type'),
          CoconutLayout.spacing_200h,
          TaprootSetupSummaryCard(
            itemList: summaryItems,
            taprootSetupSummaryCardType: TaprootSetupSummaryCardType.tree,
          ),
          CoconutLayout.spacing_400h,

          const Divider(color: CoconutColors.gray800, height: 40),
          _buildSectionTitle('Taproot Setup Summary Card - Column Type'),
          CoconutLayout.spacing_200h,
          TaprootSetupSummaryCard(
            itemList: summaryItems,
            taprootSetupSummaryCardType: TaprootSetupSummaryCardType.column,
          ),
          CoconutLayout.spacing_400h,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray400));
  }
}
