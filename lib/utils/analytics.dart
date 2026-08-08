import '../models/smoke_log.dart';
import 'time_utils.dart';

/// 기간 통계 결과.
class RangeStats {
  final DateTime fromDay;
  final DateTime toDay; // inclusive
  final int totalCount;
  final int dayCount;
  final int activeDays;
  final int sessionCount;

  /// 시간대별(24버킷, 0 = 하루 시작 시각) 개비 수.
  final List<int> hourly;

  /// 요일별(월~일) 평균 개비 수.
  final List<double> weekdayAvg;

  /// 날짜별 개비 수(기간 내 모든 날짜 포함, 0 포함).
  final Map<DateTime, int> dailyCounts;

  /// 연속 흡연(같은 논리적 하루 안) 간격 목록.
  final List<Duration> intervals;

  /// 세션 시작 간격(같은 논리적 하루 안).
  final List<Duration> sessionIntervals;

  /// 하루 첫 흡연 시각(하루 시작으로부터 경과 분) 목록.
  final List<int> firstSmokeMinutes;

  /// 하루 마지막 흡연 시각(하루 시작으로부터 경과 분) 목록.
  final List<int> lastSmokeMinutes;

  const RangeStats({
    required this.fromDay,
    required this.toDay,
    required this.totalCount,
    required this.dayCount,
    required this.activeDays,
    required this.sessionCount,
    required this.hourly,
    required this.weekdayAvg,
    required this.dailyCounts,
    required this.intervals,
    required this.sessionIntervals,
    required this.firstSmokeMinutes,
    required this.lastSmokeMinutes,
  });

  bool get isEmpty => totalCount == 0;

  /// 기간 전체 일수 기준 하루 평균.
  double get avgPerDay => dayCount == 0 ? 0 : totalCount / dayCount;

  /// 흡연한 날만 기준으로 한 하루 평균.
  double get avgPerActiveDay => activeDays == 0 ? 0 : totalCount / activeDays;

  /// 세션 1회당 평균 개비 수.
  double get avgPerSession => sessionCount == 0 ? 0 : totalCount / sessionCount;

  Duration get avgInterval => _mean(intervals);
  Duration get medianInterval => _median(intervals);
  Duration get avgSessionInterval => _mean(sessionIntervals);
  Duration get shortestInterval =>
      intervals.isEmpty ? Duration.zero : intervals.reduce((a, b) => a < b ? a : b);
  Duration get longestInterval =>
      intervals.isEmpty ? Duration.zero : intervals.reduce((a, b) => a > b ? a : b);

  /// 평균 첫 흡연 시각(하루 시작으로부터 분).
  double? get avgFirstMinutes => firstSmokeMinutes.isEmpty
      ? null
      : firstSmokeMinutes.reduce((a, b) => a + b) / firstSmokeMinutes.length;

  double? get avgLastMinutes => lastSmokeMinutes.isEmpty
      ? null
      : lastSmokeMinutes.reduce((a, b) => a + b) / lastSmokeMinutes.length;

  MapEntry<DateTime, int>? get peakDay {
    if (dailyCounts.isEmpty) return null;
    return dailyCounts.entries.reduce((a, b) => b.value > a.value ? b : a);
  }

  MapEntry<DateTime, int>? get lowestActiveDay {
    final active = dailyCounts.entries.where((e) => e.value > 0);
    if (active.isEmpty) return null;
    return active.reduce((a, b) => b.value < a.value ? b : a);
  }

  /// 가장 흡연이 많은 시간대 버킷 인덱스.
  int? get peakHourBucket {
    if (totalCount == 0) return null;
    var best = 0;
    for (var i = 1; i < hourly.length; i++) {
      if (hourly[i] > hourly[best]) best = i;
    }
    return hourly[best] == 0 ? null : best;
  }

  static Duration _mean(List<Duration> xs) {
    if (xs.isEmpty) return Duration.zero;
    final total = xs.fold<int>(0, (s, d) => s + d.inSeconds);
    return Duration(seconds: (total / xs.length).round());
  }

  static Duration _median(List<Duration> xs) {
    if (xs.isEmpty) return Duration.zero;
    final sorted = [...xs]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return Duration(
      seconds: ((sorted[mid - 1].inSeconds + sorted[mid].inSeconds) / 2).round(),
    );
  }
}

/// 기록 전체를 받아 각종 통계를 계산한다.
///
/// 흡연은 누를 때마다 1개비로 기록되고, [sessionGap] 이내에 이어지는 기록은
/// 통계상 "1회 흡연 n개비"(세션)로 묶인다.
class SmokeAnalytics {
  /// 시간 오름차순 정렬된 기록.
  final List<SmokeLog> logs;
  final DayCalculator dayCalc;
  final Duration sessionGap;

  late final Map<DateTime, List<SmokeLog>> _byDay = _groupByDay();
  late final List<SmokeSession> allSessions = buildSessions(logs, sessionGap);

  SmokeAnalytics({
    required this.logs,
    required this.dayCalc,
    required this.sessionGap,
  });

  Map<DateTime, List<SmokeLog>> _groupByDay() {
    final map = <DateTime, List<SmokeLog>>{};
    for (final log in logs) {
      map.putIfAbsent(dayCalc.dayKeyOf(log.time), () => []).add(log);
    }
    return map;
  }

  /// 연속 흡연을 세션으로 묶는다. 직전 기록과의 간격이 [gap] 이하이면 같은 세션.
  static List<SmokeSession> buildSessions(List<SmokeLog> logs, Duration gap) {
    final sessions = <SmokeSession>[];
    List<SmokeLog>? current;
    for (final log in logs) {
      if (current == null ||
          log.time.difference(current.last.time) > gap) {
        current = [log];
        sessions.add(SmokeSession(current));
      } else {
        current.add(log);
      }
    }
    return sessions;
  }

  List<SmokeLog> logsOn(DateTime dayKey) => _byDay[dayKey] ?? const [];

  int countOn(DateTime dayKey) => logsOn(dayKey).length;

  List<SmokeSession> sessionsOn(DateTime dayKey) =>
      buildSessions(logsOn(dayKey), sessionGap);

  SmokeLog? get lastLog => logs.isEmpty ? null : logs.last;

  /// 마지막 흡연으로부터 경과 시간.
  Duration? elapsedSinceLast([DateTime? now]) {
    final last = lastLog;
    if (last == null) return null;
    return (now ?? DateTime.now()).difference(last.time);
  }

  /// 기록이 있는 가장 이른 날짜.
  DateTime? get firstDay {
    if (logs.isEmpty) return null;
    return dayCalc.dayKeyOf(logs.first.time);
  }

  /// [fromDay]~[toDay](양끝 포함) 구간 통계.
  RangeStats rangeStats(DateTime fromDay, DateTime toDay) {
    final dailyCounts = <DateTime, int>{};
    final hourly = List<int>.filled(24, 0);
    final weekdaySum = List<int>.filled(7, 0);
    final weekdayDays = List<int>.filled(7, 0);
    final intervals = <Duration>[];
    final sessionIntervals = <Duration>[];
    final firstMinutes = <int>[];
    final lastMinutes = <int>[];

    var total = 0;
    var activeDays = 0;
    var sessionCount = 0;
    var dayCount = 0;

    for (var day = fromDay;
        !day.isAfter(toDay);
        day = DateTime(day.year, day.month, day.day + 1)) {
      dayCount++;
      final dayLogs = logsOn(day);
      final count = dayLogs.length;
      dailyCounts[day] = count;
      total += count;
      weekdayDays[day.weekday - 1]++;
      weekdaySum[day.weekday - 1] += count;

      if (count == 0) continue;
      activeDays++;

      for (final log in dayLogs) {
        hourly[dayCalc.hourBucketOf(log.time)]++;
      }
      for (var i = 1; i < dayLogs.length; i++) {
        intervals.add(dayLogs[i].time.difference(dayLogs[i - 1].time));
      }

      final sessions = buildSessions(dayLogs, sessionGap);
      sessionCount += sessions.length;
      for (var i = 1; i < sessions.length; i++) {
        sessionIntervals.add(sessions[i].start.difference(sessions[i - 1].start));
      }

      final dayStart = dayCalc.startOf(day);
      firstMinutes.add(dayLogs.first.time.difference(dayStart).inMinutes);
      lastMinutes.add(dayLogs.last.time.difference(dayStart).inMinutes);
    }

    final weekdayAvg = List<double>.generate(
      7,
      (i) => weekdayDays[i] == 0 ? 0 : weekdaySum[i] / weekdayDays[i],
    );

    return RangeStats(
      fromDay: fromDay,
      toDay: toDay,
      totalCount: total,
      dayCount: dayCount,
      activeDays: activeDays,
      sessionCount: sessionCount,
      hourly: hourly,
      weekdayAvg: weekdayAvg,
      dailyCounts: dailyCounts,
      intervals: intervals,
      sessionIntervals: sessionIntervals,
      firstSmokeMinutes: firstMinutes,
      lastSmokeMinutes: lastMinutes,
    );
  }

  /// 최근 [days]일(오늘 포함) 통계.
  RangeStats recentStats(int days, {DateTime? today}) {
    final end = today ?? dayCalc.today();
    final start = DateTime(end.year, end.month, end.day - (days - 1));
    return rangeStats(start, end);
  }

  /// 오늘 기준 비교값 묶음(홈 화면용).
  TodaySummary todaySummary({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = dayCalc.dayKeyOf(current);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    final todayLogs = logsOn(today);
    final todaySessions = buildSessions(todayLogs, sessionGap);

    // 최근 7일(오늘 제외) 평균.
    var sum = 0;
    var days = 0;
    for (var i = 1; i <= 7; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      if (firstDay != null && d.isBefore(firstDay!)) break;
      sum += countOn(d);
      days++;
    }
    final weekAvg = days == 0 ? null : sum / days;

    // 같은 시각까지의 어제 누적(공정 비교용).
    final elapsedToday = current.difference(dayCalc.startOf(today));
    final yesterdayStart = dayCalc.startOf(yesterday);
    final yesterdayPace = logsOn(yesterday)
        .where((l) => l.time.difference(yesterdayStart) <= elapsedToday)
        .length;

    final intervals = <Duration>[];
    for (var i = 1; i < todayLogs.length; i++) {
      intervals.add(todayLogs[i].time.difference(todayLogs[i - 1].time));
    }

    return TodaySummary(
      day: today,
      count: todayLogs.length,
      sessionCount: todaySessions.length,
      yesterdayCount: countOn(yesterday),
      yesterdayPaceCount: yesterdayPace,
      weekAverage: weekAvg,
      todayIntervals: intervals,
      firstLog: todayLogs.isEmpty ? null : todayLogs.first,
      lastLog: todayLogs.isEmpty ? null : todayLogs.last,
    );
  }
}

class TodaySummary {
  final DateTime day;
  final int count;
  final int sessionCount;
  final int yesterdayCount;

  /// 어제 같은 시각까지의 누적 개비 수.
  final int yesterdayPaceCount;
  final double? weekAverage;
  final List<Duration> todayIntervals;
  final SmokeLog? firstLog;
  final SmokeLog? lastLog;

  const TodaySummary({
    required this.day,
    required this.count,
    required this.sessionCount,
    required this.yesterdayCount,
    required this.yesterdayPaceCount,
    required this.weekAverage,
    required this.todayIntervals,
    required this.firstLog,
    required this.lastLog,
  });

  int get vsYesterday => count - yesterdayCount;
  int get vsYesterdayPace => count - yesterdayPaceCount;
  double? get vsWeekAverage => weekAverage == null ? null : count - weekAverage!;

  Duration get avgIntervalToday => RangeStats._mean(todayIntervals);
}
