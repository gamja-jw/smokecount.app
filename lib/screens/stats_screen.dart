import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/smoke_log.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/charts.dart';
import '../widgets/period_selector.dart';
import '../widgets/stat_tile.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: '일간'),
            Tab(text: '주간'),
            Tab(text: '월간'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _DailyTab(),
          _WeeklyTab(),
          _MonthlyTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 일간

class _DailyTab extends StatefulWidget {
  const _DailyTab();

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  int _offset = 0; // 0 = 오늘

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final analytics = state.analytics;
    final dayCalc = state.dayCalc;
    final today = dayCalc.today();
    final day = DateTime(today.year, today.month, today.day - _offset);

    final stats = analytics.rangeStats(day, day);
    final sessions = analytics.sessionsOn(day);
    final prevDay = DateTime(day.year, day.month, day.day - 1);
    final prevCount = analytics.countOn(prevDay);
    final week = analytics.recentStats(7, today: day);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        PeriodSelector(
          title: _offset == 0 ? '오늘' : dateFmt.format(day),
          subtitle: _offset == 0 ? dateFmt.format(day) : null,
          onPrev: () => setState(() => _offset++),
          onNext: _offset == 0 ? null : () => setState(() => _offset--),
          onTapTitle: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: day,
              firstDate: analytics.firstDay ?? DateTime(2020),
              lastDate: today,
            );
            if (picked != null) {
              setState(() => _offset = today.difference(
                    DateTime(picked.year, picked.month, picked.day),
                  ).inDays);
            }
          },
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: '요약',
          child: StatGrid(
            tiles: [
              StatTile(
                label: '총 흡연량',
                value: '${stats.totalCount}',
                unit: '개비',
                valueColor: AppColors.ember,
                sub: '전날 $prevCount개비',
                icon: Icons.smoking_rooms_rounded,
              ),
              StatTile(
                label: '흡연 세션',
                value: '${stats.sessionCount}',
                unit: '회',
                valueColor: AppColors.session,
                sub: '세션당 ${fmtNum(stats.avgPerSession)}개비',
                icon: Icons.repeat_rounded,
              ),
              StatTile(
                label: '평균 흡연 간격',
                value: stats.intervals.isEmpty
                    ? '-'
                    : formatDurationShort(stats.avgInterval),
                sub: stats.intervals.isEmpty
                    ? null
                    : '중앙값 ${formatDurationShort(stats.medianInterval)}',
                icon: Icons.timelapse_rounded,
              ),
              StatTile(
                label: '세션 간 간격',
                value: stats.sessionIntervals.isEmpty
                    ? '-'
                    : formatDurationShort(stats.avgSessionInterval),
                sub: '연속 흡연 제외',
                icon: Icons.hourglass_bottom_rounded,
              ),
              StatTile(
                label: '첫 흡연',
                value: stats.firstSmokeMinutes.isEmpty
                    ? '-'
                    : timeFmt.format(analytics.logsOn(day).first.time),
                icon: Icons.wb_twilight_rounded,
              ),
              StatTile(
                label: '마지막 흡연',
                value: stats.lastSmokeMinutes.isEmpty
                    ? '-'
                    : timeFmt.format(analytics.logsOn(day).last.time),
                icon: Icons.nightlight_round,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '최근 7일 대비',
          child: StatGrid(
            tiles: [
              DeltaChip(label: '전날 대비', delta: stats.totalCount - prevCount),
              DeltaChip(
                label: '7일 평균 대비',
                delta: week.avgPerDay == 0
                    ? null
                    : stats.totalCount - week.avgPerDay,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HourlyCard(hourly: stats.hourly, dayCalc: dayCalc),
        const SizedBox(height: 12),
        SectionCard(
          title: '세션 상세',
          trailing: Text(
            '${state.settings.sessionGapMinutes}분 이내 = 1회',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
          child: sessions.isEmpty
              ? const _EmptyHint('이 날은 기록이 없습니다.')
              : Column(children: [for (final s in sessions) _SessionRow(s)]),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SmokeSession session;

  const _SessionRow(this.session);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multi = session.count > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (multi ? AppColors.session : AppColors.ember)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${session.count}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: multi ? AppColors.session : AppColors.ember,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  multi
                      ? '${timeFmt.format(session.start)} ~ ${timeFmt.format(session.end)}'
                      : timeFmt.format(session.start),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  multi
                      ? '연속 ${session.count}개비 · ${formatDurationShort(session.span)} 동안'
                      : '1개비',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 주간

class _WeeklyTab extends StatefulWidget {
  const _WeeklyTab();

  @override
  State<_WeeklyTab> createState() => _WeeklyTabState();
}

class _WeeklyTabState extends State<_WeeklyTab> {
  int _offset = 0; // 0 = 이번 주

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final analytics = state.analytics;
    final dayCalc = state.dayCalc;
    final today = dayCalc.today();
    final thisWeek = startOfWeek(today);
    final weekStart =
        DateTime(thisWeek.year, thisWeek.month, thisWeek.day - _offset * 7);
    final weekEnd =
        DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

    // 진행 중인 주는 아직 오지 않은 날을 평균에서 빼야 한다.
    final effectiveEnd = weekEnd.isAfter(today) ? today : weekEnd;
    final elapsedDays = effectiveEnd.difference(weekStart).inDays + 1;
    final inProgress = effectiveEnd.isBefore(weekEnd);

    final stats = analytics.rangeStats(weekStart, effectiveEnd);
    final chart = analytics.rangeStats(weekStart, weekEnd);

    // 지난주도 같은 일수만 잘라서 비교한다.
    final prevStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
    final prev = analytics.rangeStats(
      prevStart,
      DateTime(prevStart.year, prevStart.month, prevStart.day + elapsedDays - 1),
    );

    final days = chart.dailyCounts.keys.toList()..sort();
    final values = days.map((d) => chart.dailyCounts[d]!.toDouble()).toList();
    final labels = days.map((d) => weekdayLabels[d.weekday - 1]).toList();
    final todayIndex = days.indexWhere((d) => isSameDate(d, today));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        PeriodSelector(
          title: _offset == 0 ? '이번 주' : '$_offset주 전',
          subtitle:
              '${shortDateFmt.format(weekStart)} ~ ${shortDateFmt.format(weekEnd)}',
          onPrev: () => setState(() => _offset++),
          onNext: _offset == 0 ? null : () => setState(() => _offset--),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: '요일별 흡연량',
          trailing: Text(
            '하루 평균 ${fmtNum(stats.avgPerDay)}개비',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.session,
                  fontWeight: FontWeight.w700,
                ),
          ),
          child: SimpleBarChart(
            values: values,
            labels: labels,
            highlightIndex: todayIndex >= 0 ? todayIndex : null,
            averageLine: stats.avgPerDay > 0 ? stats.avgPerDay : null,
            averageLabel: '평균',
            tooltipText: (i, v) =>
                '${shortDateFmt.format(days[i])} · ${v.toStringAsFixed(0)}개비',
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '요약',
          child: StatGrid(
            tiles: [
              StatTile(
                label: inProgress ? '주간 총량 (진행 중)' : '주간 총량',
                value: '${stats.totalCount}',
                unit: '개비',
                valueColor: AppColors.ember,
                sub: '지난주 같은 기간 ${prev.totalCount}개비',
                icon: Icons.smoking_rooms_rounded,
              ),
              StatTile(
                label: '하루 평균',
                value: fmtNum(stats.avgPerDay),
                unit: '개비',
                sub: '$elapsedDays일 기준 · 흡연일 ${fmtNum(stats.avgPerActiveDay)}개비',
                icon: Icons.calendar_today_rounded,
              ),
              StatTile(
                label: '흡연 세션',
                value: '${stats.sessionCount}',
                unit: '회',
                valueColor: AppColors.session,
                sub: '세션당 ${fmtNum(stats.avgPerSession)}개비',
                icon: Icons.repeat_rounded,
              ),
              StatTile(
                label: '평균 흡연 간격',
                value: stats.intervals.isEmpty
                    ? '-'
                    : formatDurationShort(stats.avgInterval),
                sub: stats.sessionIntervals.isEmpty
                    ? null
                    : '세션 간 ${formatDurationShort(stats.avgSessionInterval)}',
                icon: Icons.timelapse_rounded,
              ),
              StatTile(
                label: '가장 많은 날',
                value: stats.peakDay == null || stats.peakDay!.value == 0
                    ? '-'
                    : '${stats.peakDay!.value}개비',
                sub: stats.peakDay == null || stats.peakDay!.value == 0
                    ? null
                    : shortDateFmt.format(stats.peakDay!.key),
                icon: Icons.trending_up_rounded,
              ),
              StatTile(
                label: '금연일',
                value: '${stats.dayCount - stats.activeDays}',
                unit: '일',
                valueColor: AppColors.good,
                sub: '기록 없는 날',
                icon: Icons.spa_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: inProgress ? '지난주 같은 기간 대비' : '지난주 대비',
          child: StatGrid(
            tiles: [
              DeltaChip(
                label: '총량',
                delta: stats.totalCount - prev.totalCount,
              ),
              DeltaChip(
                label: '하루 평균',
                delta: prev.totalCount == 0
                    ? null
                    : double.parse(
                        (stats.avgPerDay - prev.avgPerDay).toStringAsFixed(1)),
              ),
              DeltaChip(
                label: '세션 수',
                delta: stats.sessionCount - prev.sessionCount,
                unit: '회',
              ),
              DeltaChip(
                label: '평균 흡연 간격',
                delta: prev.intervals.isEmpty || stats.intervals.isEmpty
                    ? null
                    : stats.avgInterval.inMinutes - prev.avgInterval.inMinutes,
                unit: '분',
                higherIsBetter: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HourlyCard(hourly: stats.hourly, dayCalc: dayCalc),
      ],
    );
  }
}

// ---------------------------------------------------------------- 월간

class _MonthlyTab extends StatefulWidget {
  const _MonthlyTab();

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  int _offset = 0; // 0 = 이번 달

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final analytics = state.analytics;
    final dayCalc = state.dayCalc;
    final today = dayCalc.today();
    final month = DateTime(today.year, today.month - _offset);
    final monthEnd = DateTime(month.year, month.month, daysInMonth(month));

    // 진행 중인 달은 아직 오지 않은 날을 평균/추세에서 제외한다.
    final effectiveEnd = monthEnd.isAfter(today) ? today : monthEnd;
    final elapsedDays = effectiveEnd.difference(month).inDays + 1;
    final inProgress = effectiveEnd.isBefore(monthEnd);

    final stats = analytics.rangeStats(month, effectiveEnd);
    final heatmap = analytics.rangeStats(month, monthEnd);

    // 지난달도 같은 일수만 잘라서 비교한다.
    final prevMonth = DateTime(month.year, month.month - 1);
    final prevDays = daysInMonth(prevMonth);
    final prev = analytics.rangeStats(
      prevMonth,
      DateTime(
        prevMonth.year,
        prevMonth.month,
        elapsedDays < prevDays ? elapsedDays : prevDays,
      ),
    );

    final days = stats.dailyCounts.keys.toList()..sort();
    final values = days.map((d) => stats.dailyCounts[d]!.toDouble()).toList();
    final labels = days.map((d) => '${d.day}').toList();

    final price = state.settings.pricePerCigarette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        PeriodSelector(
          title: monthFmt.format(month),
          subtitle: _offset == 0 ? '이번 달' : null,
          onPrev: () => setState(() => _offset++),
          onNext: _offset == 0 ? null : () => setState(() => _offset--),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: '일별 추세',
          trailing: Text(
            '하루 평균 ${fmtNum(stats.avgPerDay)}개비',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.session,
                  fontWeight: FontWeight.w700,
                ),
          ),
          child: SimpleLineChart(
            values: values,
            labels: labels,
            color: AppColors.ember,
            tooltipText: (i, v) => i < days.length
                ? '${shortDateFmt.format(days[i])} · ${v.toStringAsFixed(0)}개비'
                : '',
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '달력 히트맵',
          child: MonthHeatmap(monthKey: month, counts: heatmap.dailyCounts),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '요약',
          child: StatGrid(
            tiles: [
              StatTile(
                label: inProgress ? '월간 총량 (진행 중)' : '월간 총량',
                value: '${stats.totalCount}',
                unit: '개비',
                valueColor: AppColors.ember,
                sub: '지난달 같은 기간 ${prev.totalCount}개비',
                icon: Icons.smoking_rooms_rounded,
              ),
              StatTile(
                label: '하루 평균',
                value: fmtNum(stats.avgPerDay),
                unit: '개비',
                sub: '흡연일 ${stats.activeDays}일 / ${stats.dayCount}일',
                icon: Icons.calendar_month_rounded,
              ),
              StatTile(
                label: '흡연 세션',
                value: '${stats.sessionCount}',
                unit: '회',
                valueColor: AppColors.session,
                sub: '세션당 ${fmtNum(stats.avgPerSession)}개비',
                icon: Icons.repeat_rounded,
              ),
              StatTile(
                label: '평균 흡연 간격',
                value: stats.intervals.isEmpty
                    ? '-'
                    : formatDurationShort(stats.avgInterval),
                sub: stats.sessionIntervals.isEmpty
                    ? null
                    : '세션 간 ${formatDurationShort(stats.avgSessionInterval)}',
                icon: Icons.timelapse_rounded,
              ),
              StatTile(
                label: '최다 흡연일',
                value: stats.peakDay == null || stats.peakDay!.value == 0
                    ? '-'
                    : '${stats.peakDay!.value}개비',
                sub: stats.peakDay == null || stats.peakDay!.value == 0
                    ? null
                    : shortDateFmt.format(stats.peakDay!.key),
                icon: Icons.trending_up_rounded,
              ),
              if (price > 0)
                StatTile(
                  label: '월간 비용',
                  value: '${stats.totalCount * price}',
                  unit: '원',
                  icon: Icons.payments_rounded,
                )
              else
                StatTile(
                  label: '금연일',
                  value: '${stats.dayCount - stats.activeDays}',
                  unit: '일',
                  valueColor: AppColors.good,
                  icon: Icons.spa_rounded,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: inProgress ? '지난달 같은 기간 대비' : '지난달 대비',
          child: StatGrid(
            tiles: [
              DeltaChip(
                label: '하루 평균',
                delta: prev.totalCount == 0
                    ? null
                    : double.parse(
                        (stats.avgPerDay - prev.avgPerDay).toStringAsFixed(1)),
              ),
              DeltaChip(
                label: '세션당 개비',
                delta: prev.sessionCount == 0
                    ? null
                    : double.parse((stats.avgPerSession - prev.avgPerSession)
                        .toStringAsFixed(1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: '요일별 평균',
          child: SimpleBarChart(
            values: stats.weekdayAvg,
            labels: weekdayLabels,
            color: AppColors.session,
            height: 160,
            tooltipText: (i, v) => '${weekdayLabels[i]}요일 평균 ${fmtNum(v)}개비',
          ),
        ),
        const SizedBox(height: 12),
        _HourlyCard(hourly: stats.hourly, dayCalc: dayCalc),
      ],
    );
  }
}

// ---------------------------------------------------------------- 공통

class _HourlyCard extends StatelessWidget {
  final List<int> hourly;
  final DayCalculator dayCalc;

  const _HourlyCard({required this.hourly, required this.dayCalc});

  @override
  Widget build(BuildContext context) {
    final total = hourly.fold<int>(0, (s, v) => s + v);
    final labels = List<String>.generate(
      24,
      (i) => '${dayCalc.hourOfBucket(i)}',
    );

    String? peakText;
    if (total > 0) {
      var best = 0;
      for (var i = 1; i < hourly.length; i++) {
        if (hourly[i] > hourly[best]) best = i;
      }
      final hour = dayCalc.hourOfBucket(best);
      peakText = '피크 $hour시 (${hourly[best]}개비)';
    }

    return SectionCard(
      title: '시간대별 분포',
      trailing: peakText == null
          ? null
          : Text(
              peakText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.ember,
                    fontWeight: FontWeight.w700,
                  ),
            ),
      child: total == 0
          ? const _EmptyHint('표시할 기록이 없습니다.')
          : SimpleBarChart(
              values: hourly.map((e) => e.toDouble()).toList(),
              labels: labels,
              labelInterval: 3,
              height: 170,
              tooltipText: (i, v) =>
                  '${dayCalc.hourOfBucket(i)}시 · ${v.toStringAsFixed(0)}개비',
            ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;

  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
