import 'package:flutter_test/flutter_test.dart';
import 'package:reset/features/progress/domain/entities/daily_habit_summary_entity.dart';
import 'package:reset/features/progress/domain/usecases/calculate_progress_usecase.dart';
import 'package:reset/features/eye_rest/domain/entities/screen_activity_block.dart';

void main() {
  group('CalculateProgressUseCase & Habit Entities', () {
    late CalculateProgressUseCase useCase;

    setUp(() {
      useCase = CalculateProgressUseCase();
    });

    test('Computes overallScore cleanly without neck posture', () {
      final summary = DailyHabitSummaryEntity(
        date: '2026-11-08',
        waterMl: 2500,
        waterGoalMl: 2500,
        sunlightMinutes: 20,
        sunlightGoalMinutes: 20,
        eyeBreaks: 4,
        eyeBreaksGoal: 4,
        screenTimeSeconds: 3600,
        steps: 6000,
        stepsGoal: 6000,
      );

      final score = summary.calculateScore(eyeRestEnabled: true);
      expect(score, greaterThan(0.0));
    });

    test('ScreenActivityBlock computes duration and converts to/from Map', () {
      final start = DateTime(2026, 11, 8, 10, 0, 0);
      final end = DateTime(2026, 11, 8, 10, 30, 0);
      final block = ScreenActivityBlock(
        id: 1,
        startTime: start,
        endTime: end,
        type: ActivityType.activeScreen,
      );

      expect(block.duration.inMinutes, 30);
      expect(block.durationSeconds, 1800);
      expect(block.isActiveScreen, isTrue);

      final map = block.toMap();
      final fromMap = ScreenActivityBlock.fromMap(map);
      expect(fromMap.startTime, equals(start));
      expect(fromMap.endTime, equals(end));
      expect(fromMap.type, equals(ActivityType.activeScreen));
    });
  });
}
