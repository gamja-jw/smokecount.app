import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 메인 흡연 기록 버튼. 누를 때마다 1개비가 기록된다.
class SmokeButton extends StatefulWidget {
  final Future<void> Function() onPressed;

  /// 직전 기록이 [gap] 이내라면 "연속 흡연으로 묶임" 힌트를 보여준다.
  final bool willChainWithPrevious;
  final int chainCount;

  const SmokeButton({
    super.key,
    required this.onPressed,
    this.willChainWithPrevious = false,
    this.chainCount = 0,
  });

  @override
  State<SmokeButton> createState() => _SmokeButtonState();
}

class _SmokeButtonState extends State<SmokeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    lowerBound: 0,
    upperBound: 0.06,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // 기록됐다는 걸 화면을 안 보고도 알 수 있게 확실한 진동을 준다.
    // (vibrate가 Android의 LONG_PRESS 햅틱이라 impact 계열보다 뚜렷하다.)
    HapticFeedback.vibrate();
    await _controller.forward();
    await _controller.reverse();
    await widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: 1 - _controller.value,
            child: child,
          ),
          child: GestureDetector(
            onTap: _handleTap,
            child: Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.ember, AppColors.emberDim],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ember.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smoking_rooms_rounded, size: 52, color: Colors.white),
                  SizedBox(height: 6),
                  Text(
                    '흡연 기록',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: widget.willChainWithPrevious ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.session.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '연속 흡연 중 · 이번 세션 ${widget.chainCount}개비',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.session,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
