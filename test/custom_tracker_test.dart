import 'package:flutter_test/flutter_test.dart';
import 'package:reset/features/custom_trackers/domain/entities/custom_tracker_entity.dart';
import 'package:reset/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('CustomTrackerEntity and Database Tests', () {
    late Database inMemoryDb;
    late AppDatabase appDb;

    setUp(() {
      inMemoryDb = sqlite3.openInMemory();
      appDb = AppDatabase.instance;
      appDb.setDatabaseForTesting(inMemoryDb);
    });

    tearDown(() {
      inMemoryDb.close();
    });

    test('CustomTrackerEntity correctly computes progress and completion status', () {
      final timerTracker = CustomTrackerEntity(
        id: '1',
        name: 'Meditation',
        type: TrackerType.timer,
        targetGoal: 20,
        currentValueToday: 10,
        unit: 'mins',
        createdAt: DateTime.now(),
      );

      expect(timerTracker.progressRatio, 0.5);
      expect(timerTracker.isCompletedToday, isFalse);

      final completedTracker = timerTracker.copyWith(currentValueToday: 20);
      expect(completedTracker.progressRatio, 1.0);
      expect(completedTracker.isCompletedToday, isTrue);
    });

    test('AppDatabase CRUD operations for custom trackers', () {
      final tracker = CustomTrackerEntity(
        id: 'test_tracker_1',
        name: 'Push-ups',
        type: TrackerType.count,
        targetGoal: 30,
        unit: 'reps',
        iconCodePoint: 0xe56c,
        colorValue: 0xFFEF5350,
        reminderTime: '08:30',
        isReminderEnabled: true,
        createdAt: DateTime.now(),
      );

      // Save
      appDb.saveCustomTrackerRaw(tracker.toMap());

      // Fetch
      final all = appDb.getAllCustomTrackersRaw();
      expect(all.length, 1);
      expect(all.first['name'], 'Push-ups');
      expect(all.first['type'], 'count');
      expect(all.first['target_goal'], 30);
      expect(all.first['is_reminder_enabled'], 1);

      // Log daily values
      final now = DateTime.now();
      appDb.insertCustomTrackerLog('test_tracker_1', 10, now);
      appDb.insertCustomTrackerLog('test_tracker_1', 15, now);

      final total = appDb.getTodayCustomTrackerTotal('test_tracker_1', now);
      expect(total, 25);

      // Reset
      appDb.resetTodayCustomTracker('test_tracker_1', now);
      final afterReset = appDb.getTodayCustomTrackerTotal('test_tracker_1', now);
      expect(afterReset, 0);

      // Delete
      appDb.deleteCustomTracker('test_tracker_1');
      expect(appDb.getAllCustomTrackersRaw().isEmpty, isTrue);
    });
  });
}
