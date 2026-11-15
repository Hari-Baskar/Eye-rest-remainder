import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import '../services/system_screen_time_service.dart';
import '../../features/progress/domain/entities/daily_habit_summary_entity.dart';
import '../../features/eye_rest/domain/entities/screen_activity_block.dart';

/// AppDatabase
///
/// Local SQLite database storage engine for LifeMint.
/// Handles offline persistence for water intake, sunlight sessions, eye breaks,
/// steps/movement, daily summaries, and user preferences without external cloud dependencies.
class AppDatabase {
  static AppDatabase? _instance;
  Database? _db;

  AppDatabase._();

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  Database get db {
    if (_db == null) {
      throw StateError(
        'Database not initialized. Call AppDatabase.init() first.',
      );
    }
    return _db!;
  }

  /// Sets an in-memory database for testing purposes
  void setDatabaseForTesting(Database testDb) {
    _db = testDb;
    _createTables();
  }

  Future<void> init() async {
    if (_db != null) return;

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'lifemint.db'));
    _db = sqlite3.open(file.path);

    _createTables();

    // Clean up any previously seeded mock/dummy history and ensure strict install date boundary
    try {
      final installMillis = await SystemScreenTimeService.getAppInstallTime();
      String installDate = getSetting('app_installed_date') ?? '';
      if (installMillis > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(installMillis).toLocal();
        installDate = dt.toIso8601String().substring(0, 10);
        setSetting('app_installed_date', installDate);
      } else if (installDate.isEmpty) {
        installDate = DateTime.now().toIso8601String().substring(0, 10);
        setSetting('app_installed_date', installDate);
      }

      // Purge any screen activity blocks and summaries recorded prior to install date
      _db!.execute('DELETE FROM screen_activity_blocks WHERE substr(start_time, 1, 10) < ?', [installDate]);
      _db!.execute('DELETE FROM daily_habit_summaries WHERE date < ?', [installDate]);
    } catch (_) {}
  }

  void _createTables() {
    // Eye rest breaks table
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS eye_rest_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL
      );
    ''');

    // Key-value settings table
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Daily Habit Summary Table for Progress Tracking
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS daily_habit_summaries (
        date TEXT PRIMARY KEY,
        water_ml INTEGER NOT NULL DEFAULT 0,
        water_goal_ml INTEGER NOT NULL DEFAULT 2500,
        sunlight_minutes INTEGER NOT NULL DEFAULT 0,
        sunlight_goal_minutes INTEGER NOT NULL DEFAULT 20,
        eye_breaks INTEGER NOT NULL DEFAULT 0,
        eye_breaks_goal INTEGER NOT NULL DEFAULT 4,
        screen_time_seconds INTEGER NOT NULL DEFAULT 0,
        steps INTEGER NOT NULL DEFAULT 0,
        steps_goal INTEGER NOT NULL DEFAULT 6000,
        score REAL NOT NULL DEFAULT 0.0,
        updated_at TEXT NOT NULL
      );
    ''');

    // Custom Trackers Table
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS custom_trackers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        target_goal INTEGER NOT NULL,
        unit TEXT NOT NULL,
        icon_code_point INTEGER NOT NULL,
        color_value INTEGER NOT NULL,
        reminder_time TEXT,
        is_reminder_enabled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );
    ''');

    // Custom Tracker Daily Logs Table
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS custom_tracker_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tracker_id TEXT NOT NULL,
        value INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      );
    ''');

    // Screen Activity Blocks for Daily Rhythm Bar
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS screen_activity_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        is_screen_on INTEGER NOT NULL,
        top_apps_json TEXT,
        has_bg_audio INTEGER DEFAULT 0,
        audio_app TEXT
      );
    ''');

    try {
      _db!.execute(
        'ALTER TABLE screen_activity_blocks ADD COLUMN top_apps_json TEXT;',
      );
    } catch (_) {}
    try {
      _db!.execute(
        'ALTER TABLE screen_activity_blocks ADD COLUMN has_bg_audio INTEGER DEFAULT 0;',
      );
    } catch (_) {}
    try {
      _db!.execute(
        'ALTER TABLE screen_activity_blocks ADD COLUMN audio_app TEXT;',
      );
    } catch (_) {}

    // Gentle Reminders Log
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS gentle_reminders_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL
      );
    ''');
  }

  // --- Screen Activity Blocks & Daily Rhythm Operations ---
  int insertActivityBlock(ScreenActivityBlock block) {
    _db!.execute(
      'INSERT INTO screen_activity_blocks (start_time, end_time, is_screen_on, top_apps_json, has_bg_audio, audio_app) VALUES (?, ?, ?, ?, ?, ?)',
      [
        block.startTime.toIso8601String(),
        block.endTime.toIso8601String(),
        block.isActiveScreen ? 1 : 0,
        block.topApps.isNotEmpty
            ? jsonEncode(block.topApps.map((a) => a.toMap()).toList())
            : null,
        block.hasBackgroundAudio ? 1 : 0,
        block.audioAppName,
      ],
    );
    return _db!.lastInsertRowId;
  }

  void updateActivityBlock(int id, DateTime endTime) {
    _db!.execute(
      'UPDATE screen_activity_blocks SET end_time = ? WHERE id = ?',
      [endTime.toIso8601String(), id],
    );
  }

  List<ScreenActivityBlock> getTodayActivityBlocks(DateTime now) {
    return getActivityBlocksForDate(now);
  }

  List<ScreenActivityBlock> getActivityBlocksForDate(DateTime date) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();

    final ResultSet result = _db!.select(
      'SELECT id, start_time, end_time, is_screen_on, top_apps_json, has_bg_audio, audio_app FROM screen_activity_blocks '
      'WHERE end_time >= ? AND start_time <= ? ORDER BY start_time ASC',
      [startOfDay, endOfDay],
    );

    return result.map((row) => ScreenActivityBlock.fromMap(row)).toList();
  }

  void replaceBlocksForDate(
    DateTime date,
    List<ScreenActivityBlock> newBlocks,
  ) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();

    _db!.execute(
      'DELETE FROM screen_activity_blocks WHERE end_time >= ? AND start_time <= ?',
      [startOfDay, endOfDay],
    );

    for (final b in newBlocks) {
      insertActivityBlock(b);
    }
  }

  /// Returns the stored install date string 'YYYY-MM-DD', defaulting to today if absent.
  String getInstallDate() {
    final val = getSetting('app_installed_date');
    if (val != null && val.isNotEmpty) return val;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    setSetting('app_installed_date', todayStr);
    return todayStr;
  }

  /// Returns all distinct 'YYYY-MM-DD' dates on or after install date that have recorded screen activity blocks.
  List<String> getDistinctActivityBlockDates() {
    if (_db == null) return [];
    try {
      final installDate = getInstallDate();
      final ResultSet result = _db!.select(
        'SELECT DISTINCT substr(start_time, 1, 10) as date_str FROM screen_activity_blocks WHERE substr(start_time, 1, 10) >= ? ORDER BY date_str DESC',
        [installDate],
      );
      return result.map((row) => row['date_str'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  void insertGentleReminder(DateTime timestamp) {
    // Debounce: do not insert duplicate alerts within 60 seconds
    final startWindow =
        timestamp.subtract(const Duration(seconds: 60)).toIso8601String();
    final endWindow =
        timestamp.add(const Duration(seconds: 60)).toIso8601String();
    final ResultSet existing = _db!.select(
      'SELECT id FROM gentle_reminders_log WHERE timestamp >= ? AND timestamp <= ? LIMIT 1',
      [startWindow, endWindow],
    );
    if (existing.isNotEmpty) {
      return; // Already recorded for this alert window
    }

    _db!.execute('INSERT INTO gentle_reminders_log (timestamp) VALUES (?)', [
      timestamp.toIso8601String(),
    ]);
  }

  int getTodayGentleRemindersCount(DateTime now) {
    return getGentleRemindersCountForDate(now);
  }

  int getGentleRemindersCountForDate(DateTime date) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).toIso8601String();

    final ResultSet result = _db!.select(
      'SELECT COUNT(*) as count FROM gentle_reminders_log WHERE timestamp >= ? AND timestamp <= ?',
      [startOfDay, endOfDay],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }

  List<DateTime> getGentleReminderTimestampsForDate(DateTime date) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();

    final ResultSet result = _db!.select(
      'SELECT timestamp FROM gentle_reminders_log WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC',
      [startOfDay, endOfDay],
    );

    return result
        .map((row) => DateTime.parse(row['timestamp'] as String).toLocal())
        .toList();
  }

  // --- Eye Rest Operations ---
  void insertEyeBreak(DateTime timestamp) {
    _db!.execute('INSERT INTO eye_rest_logs (timestamp) VALUES (?)', [
      timestamp.toIso8601String(),
    ]);
  }

  int getTodayEyeBreaksCount(DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    final ResultSet result = _db!.select(
      'SELECT COUNT(*) as count FROM eye_rest_logs WHERE timestamp >= ? AND timestamp <= ?',
      [startOfDay, endOfDay],
    );

    if (result.isNotEmpty && result.first['count'] != null) {
      return result.first['count'] as int;
    }
    return 0;
  }

  List<DateTime> getEyeBreakTimestampsForDate(DateTime date) {
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();

    final ResultSet result = _db!.select(
      'SELECT timestamp FROM eye_rest_logs WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC',
      [startOfDay, endOfDay],
    );

    return result
        .map((row) => DateTime.parse(row['timestamp'] as String).toLocal())
        .toList();
  }

  // --- Settings Key-Value Operations ---
  void setSetting(String key, String value) {
    _db!.execute(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  String? getSetting(String key) {
    final ResultSet result = _db!.select(
      'SELECT value FROM app_settings WHERE key = ?',
      [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  // --- Daily Habit Summary Operations ---
  void upsertDailySummary(DailyHabitSummaryEntity summary) {
    _db!.execute(
      '''
      INSERT OR REPLACE INTO daily_habit_summaries (
        date, water_ml, water_goal_ml, sunlight_minutes, sunlight_goal_minutes,
        eye_breaks, eye_breaks_goal, screen_time_seconds, steps, steps_goal,
        score, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        summary.date,
        summary.waterMl,
        summary.waterGoalMl,
        summary.sunlightMinutes,
        summary.sunlightGoalMinutes,
        summary.eyeBreaks,
        summary.eyeBreaksGoal,
        summary.screenTimeSeconds,
        summary.steps,
        summary.stepsGoal,
        summary.overallScore,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  DailyHabitSummaryEntity? getDailySummary(String dateStr) {
    final ResultSet result = _db!.select(
      'SELECT * FROM daily_habit_summaries WHERE date = ?',
      [dateStr],
    );
    if (result.isNotEmpty) {
      return _rowToSummary(result.first);
    }
    return null;
  }

  List<DailyHabitSummaryEntity> getAllDailySummaries() {
    final ResultSet result = _db!.select(
      'SELECT * FROM daily_habit_summaries ORDER BY date ASC',
    );
    return result.map(_rowToSummary).toList();
  }

  List<DailyHabitSummaryEntity> getAllDailySummariesDesc() {
    final ResultSet result = _db!.select(
      'SELECT * FROM daily_habit_summaries ORDER BY date DESC',
    );
    return result.map(_rowToSummary).toList();
  }

  DailyHabitSummaryEntity _rowToSummary(Row row) {
    return DailyHabitSummaryEntity(
      date: row['date'] as String,
      waterMl: (row['water_ml'] as num).toInt(),
      waterGoalMl: (row['water_goal_ml'] as num).toInt(),
      sunlightMinutes: (row['sunlight_minutes'] as num).toInt(),
      sunlightGoalMinutes: (row['sunlight_goal_minutes'] as num).toInt(),
      eyeBreaks: (row['eye_breaks'] as num).toInt(),
      eyeBreaksGoal: (row['eye_breaks_goal'] as num).toInt(),
      screenTimeSeconds: (row['screen_time_seconds'] as num).toInt(),
      steps: (row['steps'] as num).toInt(),
      stepsGoal: (row['steps_goal'] as num).toInt(),
      overallScore: (row['score'] as num).toDouble(),
    );
  }

  /// Previously bootstrapped mock days for past 14 days.
  /// Now disabled so history only displays authentic user usage.
  void bootstrapHistoryIfEmpty(DateTime now) {
    // No-op: Do not generate mock/fake history for new users.
  }

  // --- Custom Trackers Database Operations ---
  List<Map<String, dynamic>> getAllCustomTrackersRaw() {
    final ResultSet result = _db!.select(
      'SELECT * FROM custom_trackers ORDER BY created_at ASC',
    );
    return result.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  void saveCustomTrackerRaw(Map<String, dynamic> trackerMap) {
    _db!.execute(
      '''
      INSERT OR REPLACE INTO custom_trackers (
        id, name, type, target_goal, unit, icon_code_point, color_value,
        reminder_time, is_reminder_enabled, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        trackerMap['id'],
        trackerMap['name'],
        trackerMap['type'],
        trackerMap['target_goal'],
        trackerMap['unit'],
        trackerMap['icon_code_point'],
        trackerMap['color_value'],
        trackerMap['reminder_time'],
        trackerMap['is_reminder_enabled'],
        trackerMap['created_at'],
      ],
    );
  }

  void deleteCustomTracker(String trackerId) {
    _db!.execute('DELETE FROM custom_trackers WHERE id = ?', [trackerId]);
    _db!.execute('DELETE FROM custom_tracker_logs WHERE tracker_id = ?', [
      trackerId,
    ]);
  }

  void insertCustomTrackerLog(String trackerId, int value, DateTime timestamp) {
    _db!.execute(
      'INSERT INTO custom_tracker_logs (tracker_id, value, timestamp) VALUES (?, ?, ?)',
      [trackerId, value, timestamp.toIso8601String()],
    );
  }

  int getTodayCustomTrackerTotal(String trackerId, DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    final ResultSet result = _db!.select(
      'SELECT SUM(value) as total FROM custom_tracker_logs WHERE tracker_id = ? AND timestamp >= ? AND timestamp <= ?',
      [trackerId, startOfDay, endOfDay],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toInt();
    }
    return 0;
  }

  void resetTodayCustomTracker(String trackerId, DateTime now) {
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    _db!.execute(
      'DELETE FROM custom_tracker_logs WHERE tracker_id = ? AND timestamp >= ? AND timestamp <= ?',
      [trackerId, startOfDay, endOfDay],
    );
  }

  void close() {
    _db?.close();
    _db = null;
  }
}
