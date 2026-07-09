import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

/// BIP39 패스프레이즈 입력 화면.
///
/// 확인 시 입력한 패스프레이즈를 [Navigator.pop] 결과로 반환한다. 취소 시 null.
class HotWalletPassphraseScreen extends StatefulWidget {
  final String title;
  final String description;

  /// 신규 설정 화면이면 true (확인 재입력 요구 + 강도 안내).
  final bool isCreating;

  /// 최소 길이(엔트로피 하한 대용). 기본 8자.
  final int minLength;

  const HotWalletPassphraseScreen({
    super.key,
    required this.title,
    required this.description,
    this.isCreating = false,
    this.minLength = 8,
  });

  @override
  State<HotWalletPassphraseScreen> createState() => _HotWalletPassphraseScreenState();
}

class _HotWalletPassphraseScreenState extends State<HotWalletPassphraseScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.clear();
    _confirmController.clear();
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  int get _strength {
    final value = _controller.text;
    int score = 0;
    if (value.length >= widget.minLength) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  void _submit() {
    final value = _controller.text;
    if (value.length < widget.minLength) {
      setState(() => _error = '패스프레이즈는 최소 ${widget.minLength}자 이상이어야 합니다.');
      return;
    }
    if (widget.isCreating) {
      if (_strength < 3) {
        setState(() => _error = '더 강한 패스프레이즈를 사용하세요. (대소문자·숫자·기호 조합 권장)');
        return;
      }
      if (value != _confirmController.text) {
        setState(() => _error = '패스프레이즈가 일치하지 않습니다.');
        return;
      }
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(title: widget.title, context: context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description, style: CoconutTypography.body2_14.setColor(CoconutColors.gray300)),
              CoconutLayout.spacing_400h,
              TextField(
                controller: _controller,
                autofocus: true,
                obscureText: _obscure,
                style: CoconutTypography.body1_16,
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  hintText: 'BIP39 패스프레이즈',
                  filled: true,
                  fillColor: CoconutColors.gray800,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: CoconutColors.gray400),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (widget.isCreating) ...[
                CoconutLayout.spacing_200h,
                TextField(
                  controller: _confirmController,
                  obscureText: _obscure,
                  style: CoconutTypography.body1_16,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    hintText: 'BIP39 패스프레이즈 확인',
                    filled: true,
                    fillColor: CoconutColors.gray800,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                CoconutLayout.spacing_200h,
                _StrengthBar(strength: _strength),
              ],
              if (_error != null) ...[
                CoconutLayout.spacing_200h,
                Text(_error!, style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink)),
              ],
              const Spacer(),
              CoconutButton(onPressed: _submit, text: widget.isCreating ? '설정' : '확인'),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int strength;

  const _StrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    const total = 5;
    final label = strength <= 2 ? '약함' : (strength <= 3 ? '보통' : '강함');
    final color = strength <= 2 ? CoconutColors.hotPink : (strength <= 3 ? CoconutColors.yellow : CoconutColors.cyan);
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: strength / total,
            backgroundColor: CoconutColors.gray700,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: CoconutTypography.body3_12.setColor(color)),
      ],
    );
  }
}
