import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/providers.dart';
import '../../domain/entities/daily_habit_summary_entity.dart';
import '../../domain/entities/progress_summary_entity.dart';
import '../../domain/usecases/calculate_progress_usecase.dart';

/// ProgressNotifier
///
/// Riverpod StateNotifier that manages the Progress state by loading daily
/// SQLite summaries, synchronizing today's real-time eye rest metrics,
/// and computing day/week/month trends and streaks.
class ProgressNotifier extends StateNotifier<ProgressSummaryEntity> {
  final AppDatabase _db;
  final CalculateProgressUseCase _useCase = CalculateProgressUseCase();
  ProgressTimeframe _selectedTimeframe = ProgressTimeframe.week;

  ProgressNotifier(this._db) : super(ProgressSummaryEntity.initial()) {
    refresh();
  }

  void setTimeframe(ProgressTimeframe timeframe) {
    _selectedTimeframe = timeframe;
    refresh();
  }

  void refresh({
    bool eyeRestEnabled = true,
  }) {
    final now = DateTime.now();
    final summaries = _db.getAllDailySummaries();

    final result = _useCase.computeProgress(
      allSummaries: summaries,
      referenceDate: now,
      timeframe: _selectedTimeframe,
      eyeRestEnabled: eyeRestEnabled,
    );

    state = result;
  }

  /// Syncs today's live eye rest metrics into SQLite and refreshes progress
  void syncToday({
    required int eyeBreaks,
    required int eyeBreaksGoal,
    required int screenSeconds,
    required bool eyeRestEnabled,
  }) {
    final now = DateTime.now();
    final dateStr = CalculateProgressUseCase.formatDate(now);

    final existing = _db.getDailySummary(dateStr);

    final effectiveScreenSeconds = max(existing?.screenTimeSeconds ?? 0, screenSeconds);
    final effectiveEyeBreaks = max(existing?.eyeBreaks ?? 0, eyeBreaks);

    final summary = DailyHabitSummaryEntity(
      date: dateStr,
      eyeBreaks: effectiveEyeBreaks,
      eyeBreaksGoal: eyeBreaksGoal,
      screenTimeSeconds: effectiveScreenSeconds,
    );

    final score = summary.calculateScore(
      eyeRestEnabled: eyeRestEnabled,
    );

    final finalSummary = summary.copyWith(overallScore: score);
    _db.upsertDailySummary(finalSummary);

    refresh(
      eyeRestEnabled: eyeRestEnabled,
    );
  }
}

final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressSummaryEntity>((ref) {
  final db = ref.watch(databaseProvider);
  final notifier = ProgressNotifier(db);

  final eyeRest = ref.watch(eyeRestProvider);

  // Sync today's live state into SQLite whenever eye rest updates
  notifier.syncToday(
    eyeBreaks: eyeRest.breaksTakenToday,
    eyeBreaksGoal: eyeRest.recommendedBreaks,
    screenSeconds: eyeRest.totalDailyScreenSeconds,
    eyeRestEnabled: eyeRest.isEnabled,
  );

  return notifier;
});
