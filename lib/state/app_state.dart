import 'package:flutter/foundation.dart';

import '../data/settings_store.dart';
import '../data/smoke_database.dart';
import '../models/smoke_log.dart';
import '../utils/analytics.dart';
import '../utils/time_utils.dart';

/// 앱 전역 상태. 기록 전체를 메모리에 두고 통계를 즉시 계산한다.
/// (하루 20개비 × 5년 ≈ 36,000건 수준이라 메모리 계산으로 충분하다.)
class AppState extends ChangeNotifier {
  final SmokeDatabase _db;
  final SettingsStore _settingsStore;

  AppState({SmokeDatabase? db, SettingsStore? settingsStore})
      : _db = db ?? SmokeDatabase(),
        _settingsStore = settingsStore ?? SettingsStore();

  bool _loading = true;
  bool get loading => _loading;

  List<SmokeLog> _logs = [];
  List<SmokeLog> get logs => List.unmodifiable(_logs);

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  SmokeAnalytics? _analytics;

  SmokeAnalytics get analytics => _analytics ??= SmokeAnalytics(
        logs: _logs,
        dayCalc: dayCalc,
        sessionGap: _settings.sessionGap,
      );

  DayCalculator get dayCalc => DayCalculator(dayStartHour: _settings.dayStartHour);

  void _invalidate() {
    _analytics = null;
    notifyListeners();
  }

  Future<void> init() async {
    _settings = await _settingsStore.load();
    _logs = await _db.loadAll();
    _loading = false;
    _invalidate();
  }

  /// 흡연 1개비 기록. 누를 때마다 1건씩 쌓인다.
  Future<SmokeLog> addSmoke([DateTime? at]) async {
    final time = at ?? DateTime.now();
    final log = await _db.insert(time);
    _insertSorted(log);
    _invalidate();
    return log;
  }

  Future<void> deleteLog(SmokeLog log) async {
    if (log.id == null) return;
    await _db.delete(log.id!);
    _logs.removeWhere((l) => l.id == log.id);
    _invalidate();
  }

  /// 잘못 누른 직후 되돌리기.
  Future<SmokeLog?> undoLast() async {
    if (_logs.isEmpty) return null;
    final last = _logs.last;
    await deleteLog(last);
    return last;
  }

  Future<void> updateLogTime(SmokeLog log, DateTime newTime) async {
    if (log.id == null) return;
    final updated = log.copyWith(time: newTime);
    await _db.update(updated);
    _logs.removeWhere((l) => l.id == log.id);
    _insertSorted(updated);
    _invalidate();
  }

  Future<void> clearAll() async {
    await _db.deleteAll();
    _logs = [];
    _invalidate();
  }

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    await _settingsStore.save(next);
    _invalidate();
  }

  /// CSV 내보내기용 문자열.
  String exportCsv() {
    final buffer = StringBuffer('datetime,epoch_ms\n');
    for (final log in _logs) {
      buffer.writeln('${log.time.toIso8601String()},${log.time.millisecondsSinceEpoch}');
    }
    return buffer.toString();
  }

  void _insertSorted(SmokeLog log) {
    var i = _logs.length;
    while (i > 0 && _logs[i - 1].time.isAfter(log.time)) {
      i--;
    }
    _logs.insert(i, log);
  }
}
