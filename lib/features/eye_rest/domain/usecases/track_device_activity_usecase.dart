import '../entities/daily_rhythm_entity.dart';
import '../entities/screen_activity_block.dart';

/// TrackDeviceActivityUseCase
///
/// Implements the "Pure Device Activity + Gentle Delivery" model:
/// 1. Physical Reality Single Source of Truth:
///    - Display ON = Active Screen Time.
///    - Display OFF / Locked = Phone Rest.
/// 2. Configurable Durations:
///    - Continuous target (e.g. 20m, 30m, 40m, or custom).
///    - Required rest duration (e.g. 20s, 1m, 2m default, 5m, or custom).
/// 3. Clean Cycle Reset (Option 1):
///    - When the 20-minute alert triggers, the session timer cleanly resets to 00:00 for the next cycle.
///    - Does NOT keep running upwards to 21m, 22m, etc.
///    - Total daily screen time continues to accumulate normally.
///    - Screen off for >= requiredRestSeconds also cleanly resets cycle to 00:00.
class TrackDeviceActivityUseCase {
  static const int kDefaultCycleSeconds = 1200; // 20 minutes
  static const int kDefaultRestThresholdSeconds = 120; // 2 minutes

  /// Handles 1-second tick when display is ON
  DailyRhythmEntity onScreenTick(DailyRhythmEntity current) {
    if (!current.isScreenOn) return current;

    final newSessionSec = current.currentSessionSeconds + 1;
    final newActiveTotal = current.activeScreenSeconds + 1;

    // Trigger alert when cycleTargetSeconds is reached (e.g. 20m = 1200s)
    final bool shouldTrigger = current.cycleTargetSeconds > 0 &&
        (newSessionSec >= current.cycleTargetSeconds);

    final int nextRemindersGiven =
        shouldTrigger ? current.remindersGiven + 1 : current.remindersGiven;
    final bool nextReminderActive =
        shouldTrigger ? true : current.isGentleReminderActive;

    // Option 1: Clean Cycle Reset
    // When the 20-minute alert triggers, reset the session timer cleanly to 0 (or modulo next lap)
    final int finalSessionSec = shouldTrigger
        ? (newSessionSec % current.cycleTargetSeconds)
        : newSessionSec;

    // Update the active block's end time
    final updatedBlocks = _updateLastBlockEndTime(
      current.blocks,
      DateTime.now(),
      ActivityType.activeScreen,
    );

    return current.copyWith(
      currentSessionSeconds: finalSessionSec,
      activeScreenSeconds: newActiveTotal,
      remindersGiven: nextRemindersGiven,
      isGentleReminderActive: nextReminderActive,
      blocks: updatedBlocks,
    );
  }

  /// Handles 1-second tick when display is OFF / Locked
  DailyRhythmEntity onScreenOffTick(DailyRhythmEntity current) {
    if (current.isScreenOn) return current;

    final newPhoneRestTotal = current.phoneRestSeconds + 1;
    final offSince = current.screenOffSince ?? DateTime.now();
    final offSeconds = DateTime.now().difference(offSince).inSeconds;

    // Meaningful rest rule: >= requiredRestSeconds of screen-off resets cycle to 0
    final threshold = current.requiredRestSeconds > 0
        ? current.requiredRestSeconds
        : kDefaultRestThresholdSeconds;
    final bool hasHadMeaningfulRest = offSeconds >= threshold;
    final int sessionSeconds =
        hasHadMeaningfulRest ? 0 : current.currentSessionSeconds;

    // Update phone rest block's end time
    final updatedBlocks = _updateLastBlockEndTime(
      current.blocks,
      DateTime.now(),
      ActivityType.phoneRest,
    );

    return current.copyWith(
      phoneRestSeconds: newPhoneRestTotal,
      currentSessionSeconds: sessionSeconds,
      blocks: updatedBlocks,
    );
  }

  /// Called when the physical display turns OFF or device is locked
  DailyRhythmEntity onScreenTurnedOff(
    DailyRhythmEntity current, {
    DateTime? timestamp,
  }) {
    if (!current.isScreenOn) return current;

    final now = timestamp ?? DateTime.now();

    // Close the active screen block up to now
    final updatedBlocks = List<ScreenActivityBlock>.from(current.blocks);
    if (updatedBlocks.isNotEmpty && updatedBlocks.last.isActiveScreen) {
      updatedBlocks[updatedBlocks.length - 1] = updatedBlocks.last.copyWith(
        endTime: now,
      );
    }

    // Start a new Phone Rest block
    updatedBlocks.add(
      ScreenActivityBlock(
        startTime: now,
        endTime: now,
        type: ActivityType.phoneRest,
      ),
    );

    return current.copyWith(
      isScreenOn: false,
      screenOffSince: now,
      blocks: updatedBlocks,
    );
  }

  /// Called when the physical display turns ON or device is unlocked
  DailyRhythmEntity onScreenTurnedOn(
    DailyRhythmEntity current, {
    DateTime? timestamp,
  }) {
    if (current.isScreenOn) return current;

    final now = timestamp ?? DateTime.now();
    final offSince = current.screenOffSince ?? now;
    final offDurationSeconds = now.difference(offSince).inSeconds;

    final threshold = current.requiredRestSeconds > 0
        ? current.requiredRestSeconds
        : kDefaultRestThresholdSeconds;

    int newSessionSeconds = current.currentSessionSeconds;
    int newPhoneRest = current.phoneRestSeconds;
    if (offDurationSeconds > 0) {
      newPhoneRest += offDurationSeconds;
    }

    if (offDurationSeconds >= threshold) {
      // Meaningful Rest taken: Reset continuous cycle to 0
      newSessionSeconds = 0;
    } else {
      // Short pause: resume from where it was paused (within current cycle)
      final target = current.cycleTargetSeconds > 0
          ? current.cycleTargetSeconds
          : kDefaultCycleSeconds;
      newSessionSeconds = current.currentSessionSeconds % target;
    }

    int effectiveActive = current.activeScreenSeconds;

    // Close the Phone Rest block up to now
    final updatedBlocks = List<ScreenActivityBlock>.from(current.blocks);
    if (updatedBlocks.isNotEmpty && updatedBlocks.last.isPhoneRest) {
      updatedBlocks[updatedBlocks.length - 1] = updatedBlocks.last.copyWith(
        endTime: now,
      );
    }

    // Start a new Active Screen block
    updatedBlocks.add(
      ScreenActivityBlock(
        startTime: now,
        endTime: now,
        type: ActivityType.activeScreen,
      ),
    );

    return current.copyWith(
      isScreenOn: true,
      clearScreenOffSince: true,
      currentSessionSeconds: newSessionSeconds,
      activeScreenSeconds: effectiveActive,
      phoneRestSeconds: newPhoneRest,
      blocks: updatedBlocks,
    );
  }

  /// Dismisses the gentle reminder banner without penalty
  DailyRhythmEntity dismissGentleReminder(DailyRhythmEntity current) {
    return current.copyWith(isGentleReminderActive: false);
  }

  /// Helper to extend the latest block's end time or append a new block
  List<ScreenActivityBlock> _updateLastBlockEndTime(
    List<ScreenActivityBlock> blocks,
    DateTime now,
    ActivityType expectedType,
  ) {
    if (blocks.isEmpty) {
      return [
        ScreenActivityBlock(
          startTime: now.subtract(const Duration(seconds: 1)),
          endTime: now,
          type: expectedType,
        ),
      ];
    }

    final last = blocks.last;
    if (last.type == expectedType) {
      final updated = List<ScreenActivityBlock>.from(blocks);
      updated[updated.length - 1] = last.copyWith(endTime: now);
      return updated;
    }

    // Block type transitioned
    final updated = List<ScreenActivityBlock>.from(blocks);
    updated.add(
      ScreenActivityBlock(
        startTime: now.subtract(const Duration(seconds: 1)),
        endTime: now,
        type: expectedType,
      ),
    );
    return updated;
  }
}
