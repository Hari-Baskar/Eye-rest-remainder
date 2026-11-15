import 'daily_habit_summary_entity.dart';

enum ProgressTimeframe {
  day,
  week,
  month,
}

/// DayBarData
///
/// Data representation for individual chart bars (e.g. Mon, Tue, etc. with score ratio 0.0 to 1.0).
class DayBarData {
  final String label; // e.g. "M", "T", "W" or "12"
  final String fullLabel; // e.g. "Mon, Oct 12"
  final double score; // 0.0 to 1.0
  final bool isToday;
  final bool isTargetMet;
  final DateTime date;

  const DayBarData({
    required this.label,
    required this.fullLabel,
    required this.score,
    this.isToday = false,
    this.isTargetMet = false,
    required this.date,
  });
}

/// ProgressSummaryEntity
///
/// Aggregate summary state calculated from local SQLite daily summaries for the selected timeframe.
class ProgressSummaryEntity {
  final ProgressTimeframe timeframe;
  final double overallConsistency; // 0.0 to 1.0 (e.g. 0.82)
  final double deltaPercentage; // e.g. +12.0 or -5.0
  final List<DayBarData> barData;
  final int waterPercentage; // e.g. 78%
  final int sunlightPercentage; // e.g. 85%
  final int eyeRestPercentage; // e.g. 76%
  final int stepsPercentage; // e.g. 68%
  final int currentStreakDays;
  final int bestStreakDays;
  final List<DailyHabitSummaryEntity> history;

  const ProgressSummaryEntity({
    this.timeframe = ProgressTimeframe.week,
    this.overallConsistency = 0.0,
    this.deltaPercentage = 0.0,
    this.barData = const [],
    this.waterPercentage = 0,
    this.sunlightPercentage = 0,
    this.eyeRestPercentage = 0,
    this.stepsPercentage = 0,
    this.currentStreakDays = 0,
    this.bestStreakDays = 0,
    this.history = const [],
  });

  factory ProgressSummaryEntity.initial() {
    return const ProgressSummaryEntity(
      timeframe: ProgressTimeframe.week,
      overallConsistency: 0.0,
      deltaPercentage: 0.0,
      barData: [],
      waterPercentage: 0,
      sunlightPercentage: 0,
      eyeRestPercentage: 0,
      stepsPercentage: 0,
      currentStreakDays: 0,
      bestStreakDays: 0,
      history: [],
    );
  }

  ProgressSummaryEntity copyWith({
    ProgressTimeframe? timeframe,
    double? overallConsistency,
    double? deltaPercentage,
    List<DayBarData>? barData,
    int? waterPercentage,
    int? sunlightPercentage,
    int? eyeRestPercentage,
    int? stepsPercentage,
    int? currentStreakDays,
    int? bestStreakDays,
    List<DailyHabitSummaryEntity>? history,
  }) {
    return ProgressSummaryEntity(
      timeframe: timeframe ?? this.timeframe,
      overallConsistency: overallConsistency ?? this.overallConsistency,
      deltaPercentage: deltaPercentage ?? this.deltaPercentage,
      barData: barData ?? this.barData,
      waterPercentage: waterPercentage ?? this.waterPercentage,
      sunlightPercentage: sunlightPercentage ?? this.sunlightPercentage,
      eyeRestPercentage: eyeRestPercentage ?? this.eyeRestPercentage,
      stepsPercentage: stepsPercentage ?? this.stepsPercentage,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      history: history ?? this.history,
    );
  }
}
