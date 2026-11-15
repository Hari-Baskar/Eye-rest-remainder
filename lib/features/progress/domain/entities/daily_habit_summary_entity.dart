/// DailyHabitSummaryEntity
///
/// Clean Architecture domain entity representing a single day's tracked health habit metrics
/// stored in the local SQLite database.
class DailyHabitSummaryEntity {
  final String date; // Format: 'YYYY-MM-DD'
  final int waterMl;
  final int waterGoalMl;
  final int sunlightMinutes;
  final int sunlightGoalMinutes;
  final int eyeBreaks;
  final int eyeBreaksGoal;
  final int screenTimeSeconds;
  final int steps;
  final int stepsGoal;
  final double overallScore; // 0.0 to 1.0

  const DailyHabitSummaryEntity({
    required this.date,
    this.waterMl = 0,
    this.waterGoalMl = 2500,
    this.sunlightMinutes = 0,
    this.sunlightGoalMinutes = 20,
    this.eyeBreaks = 0,
    this.eyeBreaksGoal = 4,
    this.screenTimeSeconds = 0,
    this.steps = 0,
    this.stepsGoal = 6000,
    this.overallScore = 0.0,
  });

  /// Calculate water compliance ratio (0.0 to 1.0)
  double get waterRatio =>
      waterGoalMl > 0 ? (waterMl / waterGoalMl.toDouble()).clamp(0.0, 1.0) : 0.0;

  /// Calculate sunlight compliance ratio (0.0 to 1.0)
  double get sunlightRatio =>
      sunlightGoalMinutes > 0 ? (sunlightMinutes / sunlightGoalMinutes.toDouble()).clamp(0.0, 1.0) : 0.0;

  /// Calculate eye rest compliance ratio (0.0 to 1.0)
  double get eyeRestRatio =>
      eyeBreaksGoal > 0 ? (eyeBreaks / eyeBreaksGoal.toDouble()).clamp(0.0, 1.0) : 0.0;

  /// Calculate steps compliance ratio (0.0 to 1.0)
  double get stepsRatio =>
      stepsGoal > 0 ? (steps / stepsGoal.toDouble()).clamp(0.0, 1.0) : 0.0;

  /// Calculates aggregate consistency score across core habits (Eye Rest)
  double calculateScore({
    bool waterEnabled = false,
    bool sunlightEnabled = false,
    bool eyeRestEnabled = true,
    bool stepsEnabled = false,
  }) {
    double totalRatio = 0.0;
    int count = 0;

    if (eyeRestEnabled) {
      totalRatio += eyeRestRatio;
      count++;
    }

    if (count == 0) return 0.0;
    return (totalRatio / count.toDouble()).clamp(0.0, 1.0);
  }

  DailyHabitSummaryEntity copyWith({
    String? date,
    int? waterMl,
    int? waterGoalMl,
    int? sunlightMinutes,
    int? sunlightGoalMinutes,
    int? eyeBreaks,
    int? eyeBreaksGoal,
    int? screenTimeSeconds,
    int? steps,
    int? stepsGoal,
    double? overallScore,
  }) {
    return DailyHabitSummaryEntity(
      date: date ?? this.date,
      waterMl: waterMl ?? this.waterMl,
      waterGoalMl: waterGoalMl ?? this.waterGoalMl,
      sunlightMinutes: sunlightMinutes ?? this.sunlightMinutes,
      sunlightGoalMinutes: sunlightGoalMinutes ?? this.sunlightGoalMinutes,
      eyeBreaks: eyeBreaks ?? this.eyeBreaks,
      eyeBreaksGoal: eyeBreaksGoal ?? this.eyeBreaksGoal,
      screenTimeSeconds: screenTimeSeconds ?? this.screenTimeSeconds,
      steps: steps ?? this.steps,
      stepsGoal: stepsGoal ?? this.stepsGoal,
      overallScore: overallScore ?? this.overallScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'water_ml': waterMl,
      'water_goal_ml': waterGoalMl,
      'sunlight_minutes': sunlightMinutes,
      'sunlight_goal_minutes': sunlightGoalMinutes,
      'eye_breaks': eyeBreaks,
      'eye_breaks_goal': eyeBreaksGoal,
      'screen_time_seconds': screenTimeSeconds,
      'steps': steps,
      'steps_goal': stepsGoal,
      'score': overallScore,
    };
  }

  factory DailyHabitSummaryEntity.fromMap(Map<String, dynamic> map) {
    return DailyHabitSummaryEntity(
      date: map['date'] as String,
      waterMl: (map['water_ml'] as num?)?.toInt() ?? 0,
      waterGoalMl: (map['water_goal_ml'] as num?)?.toInt() ?? 2500,
      sunlightMinutes: (map['sunlight_minutes'] as num?)?.toInt() ?? 0,
      sunlightGoalMinutes: (map['sunlight_goal_minutes'] as num?)?.toInt() ?? 20,
      eyeBreaks: (map['eye_breaks'] as num?)?.toInt() ?? 0,
      eyeBreaksGoal: (map['eye_breaks_goal'] as num?)?.toInt() ?? 4,
      screenTimeSeconds: (map['screen_time_seconds'] as num?)?.toInt() ?? 0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      stepsGoal: (map['steps_goal'] as num?)?.toInt() ?? 6000,
      overallScore: (map['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
