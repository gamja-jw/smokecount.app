import 'package:flutter_test/flutter_test.dart';
import 'package:smokecount/models/smoke_log.dart';
import 'package:smokecount/utils/analytics.dart';
import 'package:smokecount/utils/time_utils.dart';

SmokeLog at(int year, int month, int day, int hour, int minute) =>
    SmokeLog(time: DateTime(year, month, day, hour, minute));

void main() {
  const gap = Duration(minutes: 10);

  group('세션 묶기', () {
    test('10분 이내 연속 흡연은 한 세션 n개비로 묶인다', () {
      final logs = [
        at(2026, 8, 8, 9, 0),
        at(2026, 8, 8, 9, 6), // 6분 뒤 → 같은 세션
        at(2026, 8, 8, 9, 14), // 8분 뒤 → 같은 세션
        at(2026, 8, 8, 11, 0), // 새 세션
      ];

      final sessions = SmokeAnalytics.buildSessions(logs, gap);

      expect(sessions.length, 2);
      expect(sessions.first.count, 3);
      expect(sessions.first.span, const Duration(minutes: 14));
      expect(sessions.last.count, 1);
    });

    test('정확히 10분 간격은 같은 세션, 10분 초과는 분리된다', () {
      expect(
        SmokeAnalytics.buildSessions(
          [at(2026, 8, 8, 9, 0), at(2026, 8, 8, 9, 10)],
          gap,
        ).length,
        1,
      );
      expect(
        SmokeAnalytics.buildSessions(
          [at(2026, 8, 8, 9, 0), at(2026, 8, 8, 9, 11)],
          gap,
        ).length,
        2,
      );
    });

    test('개비 수는 세션과 무관하게 누른 횟수 그대로다', () {
      final logs = [
        at(2026, 8, 8, 9, 0),
        at(2026, 8, 8, 9, 3),
        at(2026, 8, 8, 9, 6),
      ];
      final analytics = SmokeAnalytics(
        logs: logs,
        dayCalc: const DayCalculator(),
        sessionGap: gap,
      );
      final stats = analytics.rangeStats(DateTime(2026, 8, 8), DateTime(2026, 8, 8));

      expect(stats.totalCount, 3); // 개비 수
      expect(stats.sessionCount, 1); // 흡연 횟수
      expect(stats.avgPerSession, 3);
    });
  });

  group('기간 통계', () {
    final logs = [
      // 8/6: 2개비
      at(2026, 8, 6, 8, 0),
      at(2026, 8, 6, 20, 0),
      // 8/7: 기록 없음
      // 8/8: 4개비(세션 2개)
      at(2026, 8, 8, 9, 0),
      at(2026, 8, 8, 9, 5),
      at(2026, 8, 8, 13, 0),
      at(2026, 8, 8, 13, 5),
    ];
    final analytics = SmokeAnalytics(
      logs: logs,
      dayCalc: const DayCalculator(),
      sessionGap: gap,
    );

    test('총량/일평균/금연일', () {
      final stats =
          analytics.rangeStats(DateTime(2026, 8, 6), DateTime(2026, 8, 8));

      expect(stats.totalCount, 6);
      expect(stats.dayCount, 3);
      expect(stats.activeDays, 2);
      expect(stats.avgPerDay, closeTo(2.0, 1e-9));
      expect(stats.avgPerActiveDay, closeTo(3.0, 1e-9));
      // 8/6은 12시간 간격이라 세션 2개, 8/8도 세션 2개.
      expect(stats.sessionCount, 4);
    });

    test('간격은 같은 날 안에서만 계산된다', () {
      final stats =
          analytics.rangeStats(DateTime(2026, 8, 6), DateTime(2026, 8, 8));

      // 8/6: 12시간, 8/8: 5분, 3시간 55분, 5분 → 총 4개
      expect(stats.intervals.length, 4);
      // 8/6의 08:00 → 20:00, 8/8의 09:00 → 13:00.
      expect(stats.sessionIntervals.length, 2);
      expect(
        stats.sessionIntervals,
        containsAll(const [Duration(hours: 12), Duration(hours: 4)]),
      );
    });

    test('시간대/요일 분포', () {
      final stats =
          analytics.rangeStats(DateTime(2026, 8, 6), DateTime(2026, 8, 8));

      expect(stats.hourly[9], 2);
      expect(stats.hourly[13], 2);
      expect(stats.hourly[8], 1);
      expect(stats.peakHourBucket, anyOf(9, 13));
      // 2026-08-08은 토요일.
      expect(stats.weekdayAvg[DateTime.saturday - 1], 4);
    });

    test('최다 흡연일', () {
      final stats =
          analytics.rangeStats(DateTime(2026, 8, 6), DateTime(2026, 8, 8));
      expect(stats.peakDay!.key, DateTime(2026, 8, 8));
      expect(stats.peakDay!.value, 4);
    });
  });

  group('하루 기준 시각', () {
    test('dayStartHour=4면 새벽 3시 흡연은 전날로 집계된다', () {
      const calc = DayCalculator(dayStartHour: 4);
      expect(calc.dayKeyOf(DateTime(2026, 8, 8, 3, 30)), DateTime(2026, 8, 7));
      expect(calc.dayKeyOf(DateTime(2026, 8, 8, 4, 0)), DateTime(2026, 8, 8));
    });

    test('시간 버킷은 하루 시작 시각부터 0번', () {
      const calc = DayCalculator(dayStartHour: 4);
      expect(calc.hourBucketOf(DateTime(2026, 8, 8, 4, 10)), 0);
      expect(calc.hourBucketOf(DateTime(2026, 8, 8, 3, 10)), 23);
      expect(calc.hourOfBucket(0), 4);
      expect(calc.hourOfBucket(23), 3);
    });
  });

  group('오늘 요약', () {
    test('어제 같은 시각까지의 누적과 비교한다', () {
      final logs = [
        // 어제: 09:00, 11:00, 20:00
        at(2026, 8, 7, 9, 0),
        at(2026, 8, 7, 11, 0),
        at(2026, 8, 7, 20, 0),
        // 오늘: 09:00, 09:30
        at(2026, 8, 8, 9, 0),
        at(2026, 8, 8, 9, 30),
      ];
      final analytics = SmokeAnalytics(
        logs: logs,
        dayCalc: const DayCalculator(),
        sessionGap: gap,
      );

      final summary =
          analytics.todaySummary(now: DateTime(2026, 8, 8, 12, 0));

      expect(summary.count, 2);
      expect(summary.sessionCount, 2);
      expect(summary.yesterdayCount, 3);
      expect(summary.yesterdayPaceCount, 2); // 12시까지는 어제도 2개비
      expect(summary.vsYesterday, -1);
      expect(summary.vsYesterdayPace, 0);
      expect(summary.avgIntervalToday, const Duration(minutes: 30));
    });
  });
}
