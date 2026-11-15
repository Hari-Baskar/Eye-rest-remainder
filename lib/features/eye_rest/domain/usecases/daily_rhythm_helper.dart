import 'dart:math';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/system_screen_time_service.dart';
import '../entities/daily_rhythm_entity.dart';
import '../entities/screen_activity_block.dart';
import '../../../progress/domain/entities/strain_session_detail.dart';

/// DailyRhythmHelper
///
/// Utility to query or reconstruct the complete Daily Rhythm (Active Screen & Phone Rest intervals)
/// for any given historical date.
class DailyRhythmHelper {
  /// Async loader that synchronizes real system-level usage events before returning rhythm entity
  static Future<DailyRhythmEntity> syncAndGetRhythmForDate({
    required AppDatabase db,
    required DateTime date,
    int? fallbackScreenSeconds,
    int? fallbackBreaks,
    int? requiredRestSeconds,
  }) async {
    try {
      final hasPerm = await SystemScreenTimeService.hasUsagePermission();
      if (hasPerm) {
        final res = await SystemScreenTimeService.getScreenAndRestBlocks(
          date: date,
          requiredRestSeconds: requiredRestSeconds,
        );
        if (res.blocks.isNotEmpty || res.appUsages.isNotEmpty) {
          if (res.blocks.isNotEmpty) {
            db.replaceBlocksForDate(date, res.blocks);
          }
          final base = DailyRhythmEntity(
            blocks: res.blocks,
            appUsages: res.appUsages,
            activeScreenSeconds: res.activeScreenSeconds,
            phoneRestSeconds: res.phoneRestSeconds,
            remindersGiven: fallbackBreaks ?? db.getGentleRemindersCountForDate(date),
            currentSessionSeconds: 0,
            requiredRestSeconds: requiredRestSeconds ?? 120,
            isScreenOn: date.day == DateTime.now().day &&
                date.month == DateTime.now().month &&
                date.year == DateTime.now().year,
          );
          return _populateStats(base);
        }
      }
    } catch (_) {}

    final base = getRhythmForDate(
      db: db,
      date: date,
      fallbackScreenSeconds: fallbackScreenSeconds,
      fallbackBreaks: fallbackBreaks,
    );
    return _populateStats(base);
  }

  static DailyRhythmEntity _populateStats(DailyRhythmEntity entity) {
    int maxSec = 0;
    String topApp = 'None';

    final longestStrain = StrainSessionDetail.calculateLongestStrain(
      entity.blocks,
      minRestThresholdSeconds: entity.requiredRestSeconds,
    );
    if (longestStrain != null) {
      maxSec = longestStrain.durationSeconds;
      topApp = longestStrain.topAppName;
    }

    int promptRests = 0;
    int ignoredReminders = 0;

    for (final b in entity.blocks) {
      if (b.isActiveScreen) {
        if (b.durationSeconds >= (entity.cycleTargetSeconds * 1.35)) {
          ignoredReminders++;
        } else if (b.durationSeconds >= (entity.cycleTargetSeconds * 0.90)) {
          promptRests++;
        }
      }
    }

    final total = promptRests + ignoredReminders;
    final rate = total > 0 ? (promptRests / total).clamp(0.0, 1.0) : 1.0;

    return entity.copyWith(
      longestContinuousSeconds: maxSec,
      longestContinuousApp: topApp,
      timerRespectRate: rate,
      promptRestsCount: promptRests,
      ignoredRemindersCount: ignoredReminders,
    );
  }

  /// Builds a DailyRhythmEntity for any given date using SQLite blocks or fallback summary
  static DailyRhythmEntity getRhythmForDate({
    required AppDatabase db,
    required DateTime date,
    int? fallbackScreenSeconds,
    int? fallbackBreaks,
  }) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    final recordedBlocks = db.getActivityBlocksForDate(date);
    final remindersCount = db.getGentleRemindersCountForDate(date);

    if (recordedBlocks.isNotEmpty) {
      int activeSec = 0;
      int restSec = 0;

      for (final b in recordedBlocks) {
        if (b.isActiveScreen) {
          activeSec += b.durationSeconds;
        } else {
          restSec += b.durationSeconds;
        }
      }

      // If activeSec is less than fallbackScreenSeconds (e.g., recorded earlier in day), use max
      final effectiveActive = max(activeSec, fallbackScreenSeconds ?? 0);
      final totalSecondsInSpan = isToday
          ? max(60, now.difference(DateTime(date.year, date.month, date.day)).inSeconds)
          : 86400;
      final effectiveRest = max(restSec, max(0, totalSecondsInSpan - effectiveActive));

      return DailyRhythmEntity(
        blocks: recordedBlocks,
        activeScreenSeconds: effectiveActive,
        phoneRestSeconds: effectiveRest,
        remindersGiven: max(remindersCount, fallbackBreaks ?? 0),
        currentSessionSeconds: 0,
        isScreenOn: isToday,
      );
    }

    // If no discrete blocks exist in the new table for this historical date,
    // synthesize realistic active and rest intervals from the daily summary screen time.
    final targetScreenSec = fallbackScreenSeconds ?? 0;
    final totalBreaks = fallbackBreaks ?? 0;

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = isToday ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);
    final totalDaySeconds = max(60, endOfDay.difference(startOfDay).inSeconds);

    if (targetScreenSec <= 0) {
      // Entire day was phone rest
      final allRestBlock = ScreenActivityBlock(
        startTime: startOfDay,
        endTime: endOfDay,
        type: ActivityType.phoneRest,
      );
      return DailyRhythmEntity(
        blocks: [allRestBlock],
        activeScreenSeconds: 0,
        phoneRestSeconds: totalDaySeconds,
        remindersGiven: 0,
        currentSessionSeconds: 0,
        isScreenOn: false,
      );
    }

    // Do not fabricate fake blocks - return honest recorded totals
    return DailyRhythmEntity(
      blocks: const [],
      activeScreenSeconds: min(targetScreenSec, totalDaySeconds),
      phoneRestSeconds: max(0, totalDaySeconds - min(targetScreenSec, totalDaySeconds)),
      remindersGiven: totalBreaks,
      currentSessionSeconds: 0,
      isScreenOn: isToday,
    );
  }
}
