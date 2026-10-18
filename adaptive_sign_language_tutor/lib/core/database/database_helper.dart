import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'web_practice_log_store_stub.dart'
    if (dart.library.html) 'web_practice_log_store.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null; // SQLite native bypass for web browser testing
    if (_database != null) return _database!;
    _database = await _initDB('sign_tutor.db');
    return _database;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.update('user_progress', {
            'overall_mastery': 0.0,
            'daily_streak': 0,
            'last_practice_date': '',
          });
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE lessons (
        id $idType,
        title $textType,
        category $textType,
        difficulty $textType,
        is_completed $integerType DEFAULT 0,
        mastery_score $realType DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE practice_logs (
        id $idType,
        lesson_id $integerType,
        timestamp $textType,
        dtw_accuracy_score $realType,
        execution_time_ms $integerType,
        common_error_joints $textType,
        FOREIGN KEY (lesson_id) REFERENCES lessons (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_progress (
        id $idType,
        overall_mastery $realType,
        daily_streak $integerType,
        last_practice_date $textType
      )
    ''');

    await db.rawInsert('''
      INSERT INTO lessons (title, category, difficulty, is_completed, mastery_score)
      VALUES ('Letter A (SSL)', 'Alphabet', 'Beginner', 0, 0.0),
             ('Hello', 'Greetings', 'Beginner', 0, 0.0),
             ('Thank You', 'Courtesy', 'Beginner', 0, 0.0)
    ''');

    await db.rawInsert('''
      INSERT INTO user_progress (overall_mastery, daily_streak, last_practice_date)
      VALUES (0.0, 0, '')
    ''');
  }

  // --- Safe Helper Methods with Web Fallbacks ---

  Future<List<Map<String, dynamic>>> getLessons() async {
    if (kIsWeb) {
      return [
        {
          'id': 1,
          'title': 'Letter A (SSL)',
          'category': 'Alphabet',
          'difficulty': 'Beginner',
          'is_completed': 0,
          'mastery_score': 0.0,
        },
        {
          'id': 2,
          'title': 'Hello',
          'category': 'Greetings',
          'difficulty': 'Beginner',
          'is_completed': 0,
          'mastery_score': 0.0,
        },
        {
          'id': 3,
          'title': 'Thank You',
          'category': 'Courtesy',
          'difficulty': 'Beginner',
          'is_completed': 0,
          'mastery_score': 0.0,
        },
      ];
    }
    final db = await instance.database;
    return await db!.query('lessons');
  }

  Future<Map<String, dynamic>?> getUserProgress() async {
    final logs = await getPracticeLogs();
    final bestAccuracyBySign = <String, double>{};
    final practiceDates = <DateTime>{};
    for (final log in logs) {
      final accuracy = (log['dtw_accuracy_score'] as num).toDouble();
      final title = log['lesson_title'] as String? ?? '';
      final sign = _signKeyFromTitle(title);
      if (sign != null) {
        final previousBest = bestAccuracyBySign[sign] ?? 0.0;
        if (accuracy > previousBest) bestAccuracyBySign[sign] = accuracy;
      }
      practiceDates.add(
        DateTime.parse(log['timestamp'] as String).toLocalDate(),
      );
    }
    final masteredCount = bestAccuracyBySign.values
        .where((accuracy) => accuracy >= 70.0)
        .length;
    final lastPractice = logs.isEmpty
        ? null
        : DateTime.parse(logs.first['timestamp'] as String);

    return {
      'overall_mastery': masteredCount / 38,
      'mastered_signs': masteredCount,
      'total_signs': 38,
      'daily_streak': _calculateStreak(practiceDates),
      'last_practice_date': lastPractice?.toIso8601String() ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> getPracticeLogs() async {
    if (kIsWeb) {
      final logs = readWebPracticeLogs();
      logs.sort(
        (a, b) =>
            (b['timestamp'] as String).compareTo(a['timestamp'] as String),
      );
      return logs;
    }

    final db = await instance.database;
    final rows = await db!.rawQuery('''
      SELECT practice_logs.*, lessons.title AS lesson_title
      FROM practice_logs
      LEFT JOIN lessons ON lessons.id = practice_logs.lesson_id
      ORDER BY practice_logs.timestamp DESC
    ''');
    return rows;
  }

  Future<String> getNextLetter() async {
    final logs = await getPracticeLogs();
    for (final log in logs) {
      final letter = _letterFromTitle(log['lesson_title'] as String? ?? '');
      if (letter != null) {
        final nextCode = letter.codeUnitAt(0) == 90
            ? 65
            : letter.codeUnitAt(0) + 1;
        return String.fromCharCode(nextCode);
      }
    }
    return 'A';
  }

  Future<String> getNextMonth() async {
    final logs = await getPracticeLogs();
    for (final log in logs) {
      final month = _monthFromTitle(log['lesson_title'] as String? ?? '');
      if (month != null) {
        return _months[(_months.indexOf(month) + 1) % _months.length];
      }
    }
    return _months.first;
  }

  Future<int> logPracticeSession({
    required int lessonId,
    required String lessonTitle,
    required double dtwAccuracyScore,
    required int executionTimeMs,
    required String commonErrorJoints,
  }) async {
    final log = {
      'lesson_id': lessonId,
      'lesson_title': lessonTitle,
      'timestamp': DateTime.now().toIso8601String(),
      'dtw_accuracy_score': dtwAccuracyScore,
      'execution_time_ms': executionTimeMs,
      'common_error_joints': commonErrorJoints,
    };
    if (kIsWeb) {
      appendWebPracticeLog(log);
      return 1;
    }
    final db = await instance.database;
    log.remove('lesson_title');
    return await db!.insert('practice_logs', log);
  }

  Future<int> getOrCreateLessonId({
    required String title,
    String category = 'Alphabet',
    String difficulty = 'Beginner',
  }) async {
    if (kIsWeb) return 1;

    final db = await instance.database;
    final existing = await db!.query(
      'lessons',
      columns: ['id'],
      where: 'title = ?',
      whereArgs: [title],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;

    return db.insert('lessons', {
      'title': title,
      'category': category,
      'difficulty': difficulty,
      'is_completed': 0,
      'mastery_score': 0.0,
    });
  }

  String? _letterFromTitle(String title) {
    final match = RegExp(
      r'letter\s+["\u201c]?([a-z])',
      caseSensitive: false,
    ).firstMatch(title);
    return match?.group(1)?.toUpperCase();
  }

  String? _signKeyFromTitle(String title) {
    final letter = _letterFromTitle(title);
    if (letter != null) return 'Letter $letter';
    final month = _monthFromTitle(title);
    return month == null ? null : month;
  }

  static bool isMonthTitle(String title) {
    final normalizedTitle = title.toLowerCase();
    for (final month in _months) {
      final englishMonth = _englishMonthName(month).toLowerCase();
      final normalizedMonth = month.toLowerCase();
      if (normalizedTitle.contains('month $normalizedMonth') ||
          normalizedTitle.contains('month $englishMonth') ||
          normalizedTitle.contains(normalizedMonth) ||
          normalizedTitle.contains(englishMonth)) {
        return true;
      }
    }
    return false;
  }

  String? _monthFromTitle(String title) {
    final normalizedTitle = title.toLowerCase();
    for (final month in _months) {
      final englishMonth = _englishMonthName(month);
      final normalizedMonth = month.toLowerCase();
      final normalizedEnglishMonth = englishMonth.toLowerCase();
      if (normalizedTitle.contains('month $normalizedMonth') ||
          normalizedTitle.contains('month $normalizedEnglishMonth') ||
          normalizedTitle.contains(normalizedMonth) ||
          normalizedTitle.contains(normalizedEnglishMonth)) {
        return month;
      }
    }
    return null;
  }

  int _calculateStreak(Set<DateTime> practiceDates) {
    if (practiceDates.isEmpty) return 0;

    final today = DateTime.now().toLocalDate();
    var currentDate = practiceDates.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!practiceDates.contains(currentDate)) return 0;

    var streak = 0;
    while (practiceDates.contains(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

const _months = [
  'ජනවාරි',
  'පෙබරවාරි',
  'මාර්තු',
  'අප්‍රේල්',
  'මැයි',
  'ජූනි',
  'ජූලි',
  'අගෝස්තු',
  'සැප්තැම්බර්',
  'ඔක්තෝබර්',
  'නොවැම්බර්',
  'දෙසැම්බර්',
];

const Map<String, String> _monthEnglishNames = {
  'ජනවාරි': 'January',
  'පෙබරවාරි': 'February',
  'මාර්තු': 'March',
  'අප්‍රේල්': 'April',
  'මැයි': 'May',
  'ජූනි': 'June',
  'ජූලි': 'July',
  'අගෝස්තු': 'August',
  'සැප්තැම්බර්': 'September',
  'ඔක්තෝබර්': 'October',
  'නොවැම්බර්': 'November',
  'දෙසැම්බර්': 'December',
  'January': 'January',
  'February': 'February',
  'March': 'March',
  'April': 'April',
  'May': 'May',
  'June': 'June',
  'July': 'July',
  'August': 'August',
  'September': 'September',
  'October': 'October',
  'November': 'November',
  'December': 'December',
};

String _englishMonthName(String month) => _monthEnglishNames[month] ?? month;


extension on DateTime {
  DateTime toLocalDate() {
    final local = toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
