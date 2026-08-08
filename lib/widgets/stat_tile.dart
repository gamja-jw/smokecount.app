import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

/// 숫자 하나를 크게 보여주는 작은 타일.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Color? valueColor;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 증감 표시 칩. 흡연은 줄어드는 쪽이 좋으므로 감소를 초록으로 표시한다.
class DeltaChip extends StatelessWidget {
  final String label;
  final num? delta;
  final String unit;

  /// 값이 커지는 쪽이 좋은 지표인지(예: 흡연 간격). 기본은 줄어드는 쪽이 좋다.
  final bool higherIsBetter;

  const DeltaChip({
    super.key,
    required this.label,
    required this.delta,
    this.unit = '개비',
    this.higherIsBetter = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final Color color;
    final IconData icon;
    final String text;
    if (delta == null) {
      color = AppColors.neutral;
      icon = Icons.remove_rounded;
      text = '비교 데이터 없음';
    } else if (delta! > 0) {
      color = higherIsBetter ? AppColors.good : AppColors.bad;
      icon = Icons.arrow_upward_rounded;
      text = '+${fmtNum(delta!)}$unit';
    } else if (delta! < 0) {
      color = higherIsBetter ? AppColors.bad : AppColors.good;
      icon = Icons.arrow_downward_rounded;
      text = '${fmtNum(delta!)}$unit';
    } else {
      color = AppColors.neutral;
      icon = Icons.drag_handle_rounded;
      text = '변화 없음';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
