/// 흡연 1회(=1개비) 기록.
class SmokeLog {
  final int? id;
  final DateTime time;

  const SmokeLog({this.id, required this.time});

  SmokeLog copyWith({int? id, DateTime? time}) =>
      SmokeLog(id: id ?? this.id, time: time ?? this.time);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'ts': time.millisecondsSinceEpoch,
      };

  factory SmokeLog.fromMap(Map<String, Object?> map) => SmokeLog(
        id: map['id'] as int?,
        time: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
      );
}

/// 연속 흡연 묶음. [gap] 이내에 이어진 흡연들을 한 세션(1회 흡연, n개비)으로 본다.
class SmokeSession {
  final List<SmokeLog> logs;

  SmokeSession(this.logs) : assert(logs.isNotEmpty);

  DateTime get start => logs.first.time;
  DateTime get end => logs.last.time;

  /// 세션에 포함된 개비 수.
  int get count => logs.length;

  /// 첫 개비 ~ 마지막 개비 사이 시간.
  Duration get span => end.difference(start);
}
