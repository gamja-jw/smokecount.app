import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
import '../models/smoke_log.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/analytics.dart';
import '../utils/time_utils.dart';
import '../widgets/charts.dart';
import '../widgets/elapsed_ring.dart';
import '../widgets/smoke_button.dart';
import '../widgets/stat_tile.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _record(AppState state) async {
    final log = await state.addSmoke();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text('${timeFmt.format(log.time)} 기록됨 · 오늘 ${state.analytics.countOn(state.dayCalc.today())}개비'),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () => state.deleteLog(log),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final analytics = state.analytics;
    final summary = analytics.todaySummary(now: _now);
    final settings = state.settings;

    final lastLog = analytics.lastLog;
    final elapsed = lastLog == null ? null : _now.difference(lastLog.time);

    // 링 한 바퀴 기준: 최근 7일 평균 간격(없으면 오늘 평균, 그것도 없으면 1시간).
    final recent = analytics.recentStats(7, today: summary.day);
    var reference = recent.avgInterval;
    if (reference.inSeconds <= 0) reference = summary.avgIntervalToday;
    if (reference.inSeconds <= 0) reference = const Duration(hours: 1);

    final chaining = lastLog != null &&
        _now.difference(lastLog.time) <= settings.sessionGap;
    final todaySessions = analytics.sessionsOn(summary.day);
    final currentSessionCount =
        chaining && todaySessions.isNotEmpty ? todaySessions.last.count : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmokeCount'),
        actions: [
          IconButton(
            tooltip: '기록 목록',
            icon: const Icon(Icons.list_alt_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Center(
            child: ElapsedRing(
              elapsed: elapsed,
              reference: reference,
              lastSmokeAt: lastLog?.time,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SmokeButton(
              onPressed: () => _record(state),
              willChainWithPrevious: chaining,
              chainCount: currentSessionCount,
            ),
          ),
          const SizedBox(height: 24),
          _TodayCard(summary: summary, settings: state.settings),
          const SizedBox(height: 12),
          _ComparisonCard(summary: summary),
          const SizedBox(height: 12),
          _RecentTrendCard(analytics: analytics, today: summary.day),
          const SizedBox(height: 12),
          _TodayTimelineCard(
            sessions: todaySessions,
            gapMinutes: settings.sessionGapMinutes,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '기록 총 ${state.logs.length}개비',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final TodaySummary summary;
  final AppSettings settings;

  const _TodayCard({required this.summary, required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = settings.dailyGoal;
    final price = settings.pricePerCigarette;

    return SectionCard(
      title: '오늘 ${dateFmt.format(summary.day)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${summary.count}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ember,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              Text('개비', style: theme.textTheme.titleMedium),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${summary.sessionCount}회',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.session,
                    ),
                  ),
                  Text(
                    '흡연 세션',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (goal > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (summary.count / goal).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(
                  summary.count > goal ? AppColors.bad : AppColors.good,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary.count > goal
                  ? '목표 $goal개비 초과 (+${summary.count - goal})'
                  : '목표 $goal개비까지 ${goal - summary.count}개비 남음',
              style: theme.textTheme.labelSmall?.copyWith(
                color: summary.count > goal ? AppColors.bad : AppColors.good,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '첫 흡연',
                  value: summary.firstLog == null
                      ? '-'
                      : timeFmt.format(summary.firstLog!.time),
                  icon: Icons.wb_twilight_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: '오늘 평균 간격',
                  value: summary.todayIntervals.isEmpty
                      ? '-'
                      : formatDurationShort(summary.avgIntervalToday),
                  icon: Icons.timelapse_rounded,
                ),
              ),
              if (price > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: '오늘 비용',
                    value: '${summary.count * price}',
                    unit: '원',
                    icon: Icons.payments_rounded,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final TodaySummary summary;

  const _ComparisonCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '변화 추적',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DeltaChip(
                  label: '어제 같은 시각 대비',
                  delta: summary.vsYesterdayPace,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DeltaChip(
                  label: '어제 하루 전체 대비',
                  delta: summary.vsYesterday,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DeltaChip(
                  label: '최근 7일 평균 대비',
                  delta: summary.vsWeekAverage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: '최근 7일 평균',
                  value: summary.weekAverage == null
                      ? '-'
                      : fmtNum(summary.weekAverage!),
                  unit: '개비/일',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTrendCard extends StatelessWidget {
  final SmokeAnalytics analytics;
  final DateTime today;

  const _RecentTrendCard({required this.analytics, required this.today});

  @override
  Widget build(BuildContext context) {
    final stats = analytics.recentStats(7, today: today);
    final days = stats.dailyCounts.keys.toList()..sort();
    final values = days.map((d) => stats.dailyCounts[d]!.toDouble()).toList();
    final labels = days.map((d) => weekdayLabels[d.weekday - 1]).toList();

    return SectionCard(
      title: '최근 7일',
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
        highlightIndex: days.length - 1,
        averageLine: stats.avgPerDay > 0 ? stats.avgPerDay : null,
        averageLabel: '평균',
        height: 160,
        tooltipText: (i, v) =>
            '${shortDateFmt.format(days[i])} · ${v.toStringAsFixed(0)}개비',
      ),
    );
  }
}

class _TodayTimelineCard extends StatelessWidget {
  final List<SmokeSession> sessions;
  final int gapMinutes;

  const _TodayTimelineCard({required this.sessions, required this.gapMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: '오늘 흡연 타임라인',
      trailing: Text(
        '$gapMinutes분 이내 연속 = 1회',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      child: sessions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '아직 오늘 기록이 없습니다.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final session in sessions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: (session.count > 1
                              ? AppColors.session
                              : AppColors.ember)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeFmt.format(session.start),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (session.count > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.session,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${session.count}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
