import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

/// 마지막 흡연 이후 경과 시간을 원형으로 표시한다.
///
/// 한 바퀴 = [reference](최근 평균 흡연 간격). 한 바퀴를 넘기면
/// "평균보다 오래 참고 있음"으로 보고 색이 바뀐다.
class ElapsedRing extends StatelessWidget {
  final Duration? elapsed;
  final Duration reference;
  final DateTime? lastSmokeAt;
  final double size;

  const ElapsedRing({
    super.key,
    required this.elapsed,
    required this.reference,
    required this.lastSmokeAt,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = elapsed != null;
    final refSeconds =
        reference.inSeconds <= 0 ? 3600 : reference.inSeconds;
    final ratio = hasData ? elapsed!.inSeconds / refSeconds : 0.0;
    final beyond = ratio >= 1.0;

    // 평균 간격에 도달하기 전까지는 담뱃불 계열, 넘어서면 초록.
    const warm = Color(0xFFF5B440);
    final color = !hasData
        ? AppColors.neutral
        : beyond
            ? AppColors.good
            : Color.lerp(AppColors.ember, warm, ratio.clamp(0, 1))!;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: hasData ? ratio.clamp(0.0, 1.0) : 0.0,
          overflowProgress: beyond ? ((ratio - 1).clamp(0.0, 1.0)) : 0.0,
          color: color,
          trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '마지막 흡연 이후',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasData ? formatDuration(elapsed!, withSeconds: true) : '기록 없음',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (lastSmokeAt != null)
                Text(
                  timeFmt.format(lastSmokeAt!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 4),
              if (hasData)
                Text(
                  beyond
                      ? '평균 간격 +${formatDurationShort(elapsed! - reference)}'
                      : '평균 간격까지 ${formatDurationShort(reference - elapsed!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double overflowProgress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.overflowProgress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, start, math.pi * 2, false, track);

    if (progress > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          colors: [color.withValues(alpha: 0.35), color],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect);
      canvas.drawArc(rect, start, math.pi * 2 * progress, false, arc);
    }

    // 한 바퀴를 넘어선 만큼은 안쪽에 얇은 링으로 덧그린다.
    if (overflowProgress > 0) {
      final inner = rect.deflate(stroke + 4);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.6);
      canvas.drawArc(inner, start, math.pi * 2 * overflowProgress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.overflowProgress != overflowProgress ||
      old.color != color;
}
