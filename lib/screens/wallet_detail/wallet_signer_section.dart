import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/widgets/card/multisig_signer_card.dart';
import 'package:coconut_wallet/widgets/card/role_description_card.dart';
import 'package:coconut_wallet/widgets/card/taproot_participant_card.dart';
import 'package:coconut_wallet/widgets/card/taproot_setup_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WalletSignerSection extends StatefulWidget {
  final WalletType walletType;

  const WalletSignerSection({super.key, required this.walletType});

  @override
  State<WalletSignerSection> createState() => _WalletSignerSectionState();
}

class _WalletSignerSectionState extends State<WalletSignerSection> {
  int _currentSegmentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WalletInfoViewModel>();

    if (widget.walletType == WalletType.multiSignature) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 32),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: viewModel.multisigTotalSignerCount,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return MultisigSignerCard(
              index: index,
              signer: viewModel.getSigner(index),
              masterFingerprint: viewModel.getSignerMasterFingerprint(index),
              derivationPath: viewModel.getSignerBsms(index).derivationPath,
            );
          },
        ),
      );
    }

    if (widget.walletType == WalletType.taproot) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('서명 방식', style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white)),
          ),
          CoconutLayout.spacing_200h,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CoconutSegmentedControl(
              labels: [
                _buildSegmentLabel('부모 키로', _currentSegmentIndex == 0 ? '현재 사용 중' : '기본 경로', _currentSegmentIndex == 0),
                _buildSegmentLabel('자식 키로', _currentSegmentIndex == 1 ? '현재 사용 중' : '상속 경로', _currentSegmentIndex == 1),
              ],
              isSelected: [_currentSegmentIndex == 0, _currentSegmentIndex == 1],
              onPressed: (index) => setState(() => _currentSegmentIndex = index),
            ),
          ),
          CoconutLayout.spacing_100h,
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildRoleDescriptionCard()),
          const Divider(color: CoconutColors.gray800, height: 40, indent: 16, endIndent: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TaprootSetupSummaryCard(
              itemList: [
                TaprootParticipantCard(
                  role: TaprootParticipantRole.parent,
                  isMine: true,
                  walletName: 'My Hot Wallet',
                  mfp: 'F75F7AB5',
                  derivationPath: "m/86'/1'/0'/0/0",
                ),
                TaprootParticipantCard(
                  role: TaprootParticipantRole.parent,
                  isMine: false,
                  walletName: 'Cosigner A',
                  mfp: 'A1B2C3D4',
                  derivationPath: "m/86'/1'/0'/0/1",
                ),
                TaprootParticipantCard(
                  role: TaprootParticipantRole.child,
                  isMine: false,
                  walletName: 'Heir 1',
                  mfp: 'E5F6G7H8',
                  derivationPath: "m/86'/1'/0'/0/2",
                  locktime: 1735689600,
                ),
              ],
              taprootSetupSummaryCardType: TaprootSetupSummaryCardType.column,
            ),
          ),
          const Divider(color: CoconutColors.gray800, height: 40, indent: 16, endIndent: 16),
        ],
      );
    }

    return CoconutLayout.spacing_800h;
  }

  Widget _buildSegmentLabel(String title, String subTitle, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          subTitle,
          style: CoconutTypography.caption_10.setColor(
            isSelected ? CoconutColors.gray400 : CoconutColors.gray400.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDescriptionCard() {
    final isParent = _currentSegmentIndex == 0;
    final theme = isParent ? RoleDescriptionTheme.cosigner : RoleDescriptionTheme.heir;
    final description =
        isParent
            ? '나는 이 지갑의 공동 서명자예요.\n다른 공동 서명자와 함께 서명해야 자산을 사용할 수 있어요.'
            : '나는 이 지갑의 상속자예요.\n정해진 시점이 지나면 자산을 사용할 수 있어요.';
    return RoleDescriptionCard(
      description: description,
      themeColor: theme.themeColor,
      backgroundColor: theme.backgroundColor,
      highlightPattern: theme.highlightPattern,
    );
  }
}
