import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:hotconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class MnemonicLengthToggle extends StatelessWidget {
  final int selectedLength;
  final ValueChanged<int> onChanged;

  const MnemonicLengthToggle({super.key, required this.selectedLength, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CoconutSegmentedControl(
      isSelected: [selectedLength == 12, selectedLength == 24],
      onPressed: (index) => onChanged(index == 0 ? 12 : 24),
      children: [Text(t.hot_wallet.mnemonic_length_12), Text(t.hot_wallet.mnemonic_length_24)],
    );
  }
}
