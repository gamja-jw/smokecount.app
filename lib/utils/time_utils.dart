import 'package:intl/intl.dart';

/// 하루의 시작 시각을 기준으로 "논리적 날짜"를 계산한다.
///
/// 새벽 흡연을 전날로 묶고 싶은 경우가 많아 [dayStartHour]를 조절할 수 있다.
/// (예: 4로 두면 03:50 흡연은 전날 기록으로 집계된다.)
class DayCalculator {
  final int dayStartHour;

  const DayCalculator({this.dayStartHour = 0});

  /// [t]가 속한 논리적 날짜(자정 기준 DateTime).
  DateTime dayKeyOf(DateTime t) {
    final shifted = t.subtract(Duration(hours: dayStartHour));
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  /// 논리적 날짜 [dayKey]가 실제로 시작하는 시각.
  DateTime startOf(DateTime dayKey) =>
      DateTime(dayKey.year, dayKey.month, dayKey.day, dayStartHour);

  /// 논리적 날짜 [dayKey]가 끝나는 시각(다음 날 시작).
  DateTime endOf(DateTime dayKey) =>
      startOf(dayKey).add(const Duration(days: 1));

  /// 24개 시간 버킷에서 [t]가 들어갈 인덱스(0 = dayStartHour).
  int hourBucketOf(DateTime t) => (t.hour - dayStartHour + 24) % 24;

  /// 시간 버킷 인덱스에 해당하는 실제 시(hour).
  int hourOfBucket(int bucket) => (bucket + dayStartHour) % 24;

  DateTime today() => dayKeyOf(DateTime.now());
}

/// 주의 시작(월요일) 날짜.
DateTime startOfWeek(DateTime dayKey) =>
    dayKey.subtract(Duration(days: dayKey.weekday - 1));

/// 달의 시작 날짜.
DateTime startOfMonth(DateTime dayKey) => DateTime(dayKey.year, dayKey.month);

/// 해당 달의 일수.
int daysInMonth(DateTime monthKey) =>
    DateTime(monthKey.year, monthKey.month + 1, 0).day;

/// 날짜만 같은지 비교.
bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const List<String> weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

final DateFormat dateFmt = DateFormat('M월 d일 (E)', 'ko');
final DateFormat shortDateFmt = DateFormat('M/d');
final DateFormat monthFmt = DateFormat('yyyy년 M월', 'ko');
final DateFormat timeFmt = DateFormat('HH:mm');
final DateFormat fullTimeFmt = DateFormat('M월 d일 HH:mm', 'ko');

/// 초 단위를 "1시간 23분" 형태로.
String formatDuration(Duration d, {bool withSeconds = false}) {
  if (d.isNegative) d = Duration.zero;
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;

  if (days > 0) return '$days일 $hours시간';
  if (hours > 0) return '$hours시간 $minutes분';
  if (minutes > 0) {
    return withSeconds ? '$minutes분 $seconds초' : '$minutes분';
  }
  return '$seconds초';
}

/// 통계용 짧은 표기: "1시간 23분" → "1h 23m" 대신 한글 축약.
String formatDurationShort(Duration d) {
  if (d.inMinutes < 1) return '1분 미만';
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours > 0) return minutes == 0 ? '$hours시간' : '$hours시간 $minutes분';
  return '$minutes분';
}

/// 소수점 1자리(정수면 정수로).
String fmtNum(num v, {int digits = 1}) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(digits);
}
