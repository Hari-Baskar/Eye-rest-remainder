import 'package:flutter_test/flutter_test.dart';
import 'package:reset/features/eye_rest/domain/entities/daily_rhythm_entity.dart';
import 'package:reset/features/eye_rest/domain/entities/screen_activity_block.dart';
import 'package:reset/features/eye_rest/domain/usecases/track_device_activity_usecase.dart';

void main() {
  group('TrackDeviceActivityUseCase (Pure Device Activity + Gentle Delivery)', () {
    late TrackDeviceActivityUseCase useCase;

    setUp(() {
      useCase = TrackDeviceActivityUseCase();
    });

    test('Session timer increments and updates active block when display is ON', () {
      final initial = DailyRhythmEntity.initial();
      expect(initial.isScreenOn, isTrue);
      expect(initial.currentSessionSeconds, 0);

      final next = useCase.onScreenTick(initial);
      expect(next.currentSessionSeconds, 1);
      expect(next.activeScreenSeconds, 1);
      expect(next.blocks.isNotEmpty, isTrue);
      expect(next.blocks.last.isActiveScreen, isTrue);
    });

    test('Micro-pause rule: screen off for < 1 minute pauses session timer and resumes', () {
      var state = DailyRhythmEntity.initial().copyWith(
        currentSessionSeconds: 500,
        activeScreenSeconds: 500,
      );

      final offTime = DateTime(2026, 11, 8, 14, 0, 0);
      // Turn screen OFF
      state = useCase.onScreenTurnedOff(state, timestamp: offTime);
      expect(state.isScreenOn, isFalse);
      expect(state.screenOffSince, equals(offTime));
      expect(state.currentSessionSeconds, 500);

      // Re-open screen 45 seconds later (< 1 minute micro-pause)
      final onTime = offTime.add(const Duration(seconds: 45));
      state = useCase.onScreenTurnedOn(state, timestamp: onTime);

      expect(state.isScreenOn, isTrue);
      expect(state.screenOffSince, isNull);
      // Session timer was paused and is preserved!
      expect(state.currentSessionSeconds, 500);
    });

    test('Meaningful rest rule: screen off for >= 2 minutes resets 20-min cycle to 0', () {
      var state = DailyRhythmEntity.initial().copyWith(
        currentSessionSeconds: 800,
        activeScreenSeconds: 800,
      );

      final offTime = DateTime(2026, 11, 8, 14, 0, 0);
      // Turn screen OFF
      state = useCase.onScreenTurnedOff(state, timestamp: offTime);

      // Re-open screen after 2 minutes and 30 seconds (150s >= 120s meaningful rest)
      final onTime = offTime.add(const Duration(seconds: 150));
      state = useCase.onScreenTurnedOn(state, timestamp: onTime);

      expect(state.isScreenOn, isTrue);
      // Meaningful rest reset cycle to 0!
      expect(state.currentSessionSeconds, 0);
    });

    test('20-minute cycle trigger delivers gentle reminder and silently rolls to next cycle', () {
      var state = DailyRhythmEntity.initial().copyWith(
        cycleTargetSeconds: 1200,
        currentSessionSeconds: 1199,
        activeScreenSeconds: 1199,
        remindersGiven: 0,
      );

      // 1200th second tick
      state = useCase.onScreenTick(state);

      expect(state.isGentleReminderActive, isTrue);
      expect(state.remindersGiven, 1);
      // Silently rolls into next 20-minute cycle without penalties
      expect(state.currentSessionSeconds, 0);
      expect(state.activeScreenSeconds, 1200);

      // 1201st second tick (first second of next cycle)
      state = useCase.onScreenTick(state);
      expect(state.currentSessionSeconds, 1);
      expect(state.activeScreenSeconds, 1201);

      // User dismisses gentle reminder without penalty
      state = useCase.dismissGentleReminder(state);
      expect(state.isGentleReminderActive, isFalse);
    });
  });
}
