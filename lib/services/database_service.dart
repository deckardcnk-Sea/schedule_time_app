import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task_model.dart';

/// 本地 SQLite 存储 + JSON 导出/导入备份
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'schedule_time.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            note TEXT,
            start INTEGER NOT NULL,
            end INTEGER NOT NULL,
            colorValue INTEGER NOT NULL,
            isAllDay INTEGER NOT NULL DEFAULT 0,
            isDone INTEGER NOT NULL DEFAULT 0,
            isReminder INTEGER NOT NULL DEFAULT 0,
            isFlagged INTEGER NOT NULL DEFAULT 0,
            category TEXT,
            listName TEXT,
            repeatRule TEXT NOT NULL DEFAULT '永不',
            reminderOffset TEXT NOT NULL DEFAULT '无',
            createdAt INTEGER NOT NULL,
            seriesId INTEGER,
            occurrenceDate INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS tasks');
          await db.execute('''
            CREATE TABLE tasks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              note TEXT,
              start INTEGER NOT NULL,
              end INTEGER NOT NULL,
              colorValue INTEGER NOT NULL,
              isAllDay INTEGER NOT NULL DEFAULT 0,
              isDone INTEGER NOT NULL DEFAULT 0,
              isReminder INTEGER NOT NULL DEFAULT 0,
              isFlagged INTEGER NOT NULL DEFAULT 0,
              category TEXT,
              listName TEXT,
              repeatRule TEXT NOT NULL DEFAULT '永不',
              reminderOffset TEXT NOT NULL DEFAULT '无',
              createdAt INTEGER NOT NULL,
              seriesId INTEGER,
              occurrenceDate INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          // 已存在旧表，安全加列，不丢数据
          await db.execute(
              "ALTER TABLE tasks ADD COLUMN repeatRule TEXT NOT NULL DEFAULT '永不'");
          await db.execute(
              "ALTER TABLE tasks ADD COLUMN reminderOffset TEXT NOT NULL DEFAULT '无'");
        }
        if (oldVersion < 4) {
          // 关键修复：Task.toMap() 含 seriesId/occurrenceDate，
          // 老版本表无这两列会导致 db.insert 抛 "no such column" 崩溃（新建任务白屏）。
          // 安全加列，不丢历史数据。
          await db.execute("ALTER TABLE tasks ADD COLUMN seriesId INTEGER");
          await db.execute(
              "ALTER TABLE tasks ADD COLUMN occurrenceDate INTEGER");
        }
      },
    );
  }

  Future<int> insert(Task t) async {
    final db = await database;
    return db.insert('tasks', t.toMap()..remove('id'));
  }

  Future<int> update(Task t) async {
    final db = await database;
    return db.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> allTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'start ASC');
    return rows.map(Task.fromMap).toList();
  }

  /// 某天的任务（含跨天判断）
  Future<List<Task>> tasksOfDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'start < ? AND end > ?',
      whereArgs: [
        endOfDay.millisecondsSinceEpoch,
        startOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'start ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  /// 导出为 JSON 文件，返回文件路径
  /// [categories]/[activities] 为可选的个人偏好（含颜色），一并写入备份
  Future<String> exportBackup(
      {List<Map<String, dynamic>>? categories,
      List<Map<String, dynamic>>? activities}) async {
    final tasks = await allTasks();
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      if (categories != null) 'categories': categories,
      if (activities != null) 'activities': activities,
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path,
        'backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  /// 从 JSON 导入（合并去重：已存在的任务跳过，避免重复导入翻倍）
  /// 去重键：title + start + end + colorValue
  Future<int> importBackup(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = (data['tasks'] as List).cast<Map<String, dynamic>>();
    final existing = await allTasks();
    final seen = <String>{};
    for (final t in existing) {
      seen.add(_dedupKey(t.title, t.start, t.end, t.colorValue));
    }
    int count = 0;
    for (final m in list) {
      final t = Task.fromMap(m);
      final key = _dedupKey(t.title, t.start, t.end, t.colorValue);
      if (seen.contains(key)) continue; // 已存在则跳过
      await insert(t);
      seen.add(key);
      count++;
    }
    return count;
  }

  String _dedupKey(String title, DateTime start, DateTime end, int color) =>
      '$title|${start.millisecondsSinceEpoch}|${end.millisecondsSinceEpoch}|$color';
}
