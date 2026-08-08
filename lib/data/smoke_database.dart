import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/smoke_log.dart';

/// 로컬 SQLite 저장소. 서버 없이 기기 안에만 데이터를 둔다.
class SmokeDatabase {
  static const _dbName = 'smokecount.db';
  static const _table = 'smoke_logs';

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_${_table}_ts ON $_table (ts)');
      },
    );
  }

  Future<List<SmokeLog>> loadAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'ts ASC');
    return rows.map(SmokeLog.fromMap).toList();
  }

  Future<SmokeLog> insert(DateTime time) async {
    final db = await _database;
    final id = await db.insert(_table, {'ts': time.millisecondsSinceEpoch});
    return SmokeLog(id: id, time: time);
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> update(SmokeLog log) async {
    final db = await _database;
    await db.update(
      _table,
      {'ts': log.time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<void> deleteAll() async {
    final db = await _database;
    await db.delete(_table);
  }

  /// 백업 복원 등에서 여러 건을 한 번에 넣는다.
  Future<void> insertMany(Iterable<DateTime> times) async {
    final db = await _database;
    final batch = db.batch();
    for (final t in times) {
      batch.insert(_table, {'ts': t.millisecondsSinceEpoch});
    }
    await batch.commit(noResult: true);
  }
}
