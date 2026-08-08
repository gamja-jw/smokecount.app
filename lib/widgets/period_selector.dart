import 'package:flutter/material.dart';

/// 기간 이동 헤더(◀ 기간 ▶).
class PeriodSelector extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onTapTitle;

  const PeriodSelector({
    super.key,
    required this.title,
    this.subtitle,
    this.onPrev,
    this.onNext,
    this.onTapTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onTapTitle,
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// 통계 타일을 2열로 배치한다.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;

  const StatGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      // 두 타일의 높이를 맞추려면 Row에 stretch가 필요하고,
      // stretch는 높이가 확정돼야 하므로 IntrinsicHeight로 감싼다.
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
