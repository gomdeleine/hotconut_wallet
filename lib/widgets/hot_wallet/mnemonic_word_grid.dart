import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class MnemonicWordGrid extends StatelessWidget {
  final String mnemonic;

  const MnemonicWordGrid({super.key, required this.mnemonic});

  @override
  Widget build(BuildContext context) {
    final words = mnemonic.split(' ');

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 34,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: CoconutColors.gray800, borderRadius: BorderRadius.circular(8)),
          child: Text('${index + 1}. ${words[index]}', style: CoconutTypography.body3_12),
        );
      },
    );
  }
}
