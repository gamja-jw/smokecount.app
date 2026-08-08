import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 막대 그래프. 값이 모두 0이어도 축이 무너지지 않도록 최소 눈금을 보장한다.
class SimpleBarChart extends StatelessWidget {
  final List<double> values;

  /// x축 라벨. 비어 있으면 라벨을 그리지 않는다.
  final List<String> labels;

  /// 강조할 막대(예: 오늘).
  final int? highlightIndex;

  /// 평균선 표시값.
  final double? averageLine;
  final String? averageLabel;
  final Color color;
  final double height;

  /// x 라벨을 몇 개마다 표시할지. null이면 자동.
  final int? labelInterval;

  /// 툴팁 문구.
  final String Function(int index, double value)? tooltipText;

  const SimpleBarChart({
    super.key,
    required this.values,
    this.labels = const [],
    this.highlightIndex,
    this.averageLine,
    this.averageLabel,
    this.color = AppColors.ember,
    this.height = 180,
    this.labelInterval,
    this.tooltipText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    final maxY = _niceMax(maxValue);
    final step = labelInterval ??
        (values.length <= 8 ? 1 : (values.length / 8).ceil());

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              tooltipPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final i = group.x;
                final text = tooltipText?.call(i, rod.toY) ??
                    '${rod.toY.toStringAsFixed(0)}개비';
                return BarTooltipItem(
                  text,
                  TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: onSurface.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 10,
                        color: onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels.isNotEmpty,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % step != 0 && i != highlightIndex) {
                    return const SizedBox.shrink();
                  }
                  final isHighlight = i == highlightIndex;
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isHighlight ? FontWeight.w800 : FontWeight.w400,
                        color: isHighlight
                            ? color
                            : onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: averageLine == null
              ? const ExtraLinesData()
              : ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: averageLine!,
                      color: AppColors.session.withValues(alpha: 0.7),
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: averageLabel != null,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.session,
                        ),
                        labelResolver: (_) => averageLabel!,
                      ),
                    ),
                  ],
                ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: _barWidth(values.length),
                    borderRadius: BorderRadius.circular(4),
                    color: i == highlightIndex
                        ? color
                        : color.withValues(alpha: 0.45),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: onSurface.withValues(alpha: 0.03),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static double _barWidth(int count) {
    if (count <= 7) return 22;
    if (count <= 12) return 16;
    if (count <= 24) return 9;
    return 6;
  }

  static double _niceMax(double maxValue) {
    if (maxValue <= 4) return 4;
    return (maxValue / 4).ceil() * 4;
  }
}

/// 추세 라인 차트.
class SimpleLineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final String Function(int index, double value)? tooltipText;

  const SimpleLineChart({
    super.key,
    required this.values,
    this.labels = const [],
    this.color = AppColors.session,
    this.height = 170,
    this.tooltipText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final maxValue = values.isEmpty ? 0.0 : values.reduce(math.max);
    final maxY = SimpleBarChart._niceMax(maxValue);
    final step = values.length <= 8 ? 1 : (values.length / 6).ceil();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: (values.length - 1).toDouble().clamp(1, double.infinity),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      tooltipText?.call(s.x.toInt(), s.y) ??
                          s.y.toStringAsFixed(1),
                      TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: onSurface.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) => value == 0
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 10,
                            color: onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: labels.isNotEmpty,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length || i % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: values.length <= 14,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 달력형 히트맵(월간 통계용).
class MonthHeatmap extends StatelessWidget {
  final DateTime monthKey;
  final Map<DateTime, int> counts;
  final void Function(DateTime day)? onTapDay;

  const MonthHeatmap({
    super.key,
    required this.monthKey,
    required this.counts,
    this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final first = DateTime(monthKey.year, monthKey.month);
    final total = DateTime(monthKey.year, monthKey.month + 1, 0).day;
    final leading = first.weekday - 1; // 월요일 시작
    final maxCount = counts.values.isEmpty
        ? 0
        : counts.values.reduce(math.max);
    final today = DateTime.now();

    Color cellColor(int count) {
      if (count == 0) return onSurface.withValues(alpha: 0.05);
      final ratio = maxCount == 0 ? 0.0 : count / maxCount;
      return Color.lerp(
        AppColors.ember.withValues(alpha: 0.25),
        AppColors.ember,
        ratio,
      )!;
    }

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= total; day++) {
      final date = DateTime(monthKey.year, monthKey.month, day);
      final count = counts[date] ?? 0;
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      cells.add(
        GestureDetector(
          onTap: onTapDay == null ? null : () => onTapDay!(date),
          child: Container(
            decoration: BoxDecoration(
              color: cellColor(count),
              borderRadius: BorderRadius.circular(7),
              border: isToday
                  ? Border.all(color: theme.colorScheme.onSurface, width: 1.4)
                  : null,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 10,
                    color: onSurface.withValues(alpha: count > 0 ? 0.9 : 0.35),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in const ['월', '화', '수', '목', '금', '토', '일'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
          children: cells,
        ),
      ],
    );
  }
}
