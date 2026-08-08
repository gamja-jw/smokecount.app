import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 설정 값.
class AppSettings {
  /// 연속 흡연으로 묶을 최대 간격(분). 기본 10분.
  final int sessionGapMinutes;

  /// 하루의 시작 시각(0~6). 새벽 흡연을 전날로 집계하고 싶을 때 사용.
  final int dayStartHour;

  /// 하루 목표 개비 수. 0이면 사용 안 함.
  final int dailyGoal;

  /// 한 개비당 가격(원). 0이면 비용 표시 안 함.
  final int pricePerCigarette;

  const AppSettings({
    this.sessionGapMinutes = 10,
    this.dayStartHour = 0,
    this.dailyGoal = 0,
    this.pricePerCigarette = 0,
  });

  Duration get sessionGap => Duration(minutes: sessionGapMinutes);

  AppSettings copyWith({
    int? sessionGapMinutes,
    int? dayStartHour,
    int? dailyGoal,
    int? pricePerCigarette,
  }) =>
      AppSettings(
        sessionGapMinutes: sessionGapMinutes ?? this.sessionGapMinutes,
        dayStartHour: dayStartHour ?? this.dayStartHour,
        dailyGoal: dailyGoal ?? this.dailyGoal,
        pricePerCigarette: pricePerCigarette ?? this.pricePerCigarette,
      );
}

class SettingsStore {
  static const _kGap = 'session_gap_minutes';
  static const _kDayStart = 'day_start_hour';
  static const _kGoal = 'daily_goal';
  static const _kPrice = 'price_per_cigarette';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      sessionGapMinutes: prefs.getInt(_kGap) ?? 10,
      dayStartHour: prefs.getInt(_kDayStart) ?? 0,
      dailyGoal: prefs.getInt(_kGoal) ?? 0,
      pricePerCigarette: prefs.getInt(_kPrice) ?? 0,
    );
  }

  Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGap, s.sessionGapMinutes);
    await prefs.setInt(_kDayStart, s.dayStartHour);
    await prefs.setInt(_kGoal, s.dailyGoal);
    await prefs.setInt(_kPrice, s.pricePerCigarette);
  }
}
