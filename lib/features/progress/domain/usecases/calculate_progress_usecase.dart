import 'dart:math';
import '../entities/daily_habit_summary_entity.dart';
import '../entities/progress_summary_entity.dart';

/// CalculateProgressUseCase
///
/// Clean Architecture use case that processes raw daily habit summary entries from SQLite
/// and computes consistency ratings, bar graphs, habit breakdowns, and streaks.
class CalculateProgressUseCase {
  static const List<String> _weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> _fullDayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  ProgressSummaryEntity computeProgress({
    required List<DailyHabitSummaryEntity> allSummaries,
    required DateTime referenceDate,
    ProgressTimeframe timeframe = ProgressTimeframe.week,
    bool waterEnabled = true,
    bool sunlightEnabled = true,
    bool eyeRestEnabled = true,
    bool stepsEnabled = true,
  }) {
    // Map summaries by date string 'YYYY-MM-DD'
    final Map<String, DailyHabitSummaryEntity> summaryMap = {
      for (final s in allSummaries) s.date: s,
    };

    final streaks = _calculateStreaks(allSummaries, referenceDate);

    switch (timeframe) {
      case ProgressTimeframe.day:
        return _computeDaySummary(
          summaryMap: summaryMap,
          referenceDate: referenceDate,
          currentStreak: streaks['current']!,
          bestStreak: streaks['best']!,
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
      case ProgressTimeframe.week:
        return _computeWeekSummary(
          summaryMap: summaryMap,
          referenceDate: referenceDate,
          currentStreak: streaks['current']!,
          bestStreak: streaks['best']!,
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
      case ProgressTimeframe.month:
        return _computeMonthSummary(
          summaryMap: summaryMap,
          referenceDate: referenceDate,
          currentStreak: streaks['current']!,
          bestStreak: streaks['best']!,
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
    }
  }

  /// Format Date to 'YYYY-MM-DD'
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Computes Week Summary (Monday to Sunday of reference week)
  ProgressSummaryEntity _computeWeekSummary({
    required Map<String, DailyHabitSummaryEntity> summaryMap,
    required DateTime referenceDate,
    required int currentStreak,
    required int bestStreak,
    required bool waterEnabled,
    required bool sunlightEnabled,
    required bool eyeRestEnabled,
    required bool stepsEnabled,
  }) {
    // Monday of current week (weekday: 1=Mon, 7=Sun)
    final monday = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
    final currentWeekDays = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day + i));

    final List<DayBarData> barData = [];
    double totalScore = 0.0;
    double totalWater = 0.0;
    double totalSunlight = 0.0;
    double totalEyeRest = 0.0;
    double totalSteps = 0.0;
    int dayCount = 0;

    final todayStr = formatDate(referenceDate);

    for (int i = 0; i < currentWeekDays.length; i++) {
      final date = currentWeekDays[i];
      final dateStr = formatDate(date);
      final isToday = dateStr == todayStr;
      final summary = summaryMap[dateStr];

      double score = 0.0;
      if (summary != null) {
        score = summary.calculateScore(
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
        totalWater += summary.waterRatio;
        totalSunlight += summary.sunlightRatio;
        totalEyeRest += summary.eyeRestRatio;
        totalSteps += summary.stepsRatio;
      }

      // Only count days up to today for the average
      if (!date.isAfter(DateTime(referenceDate.year, referenceDate.month, referenceDate.day))) {
        totalScore += score;
        dayCount++;
      }

      barData.add(DayBarData(
        label: _weekDayLabels[i],
        fullLabel: '${_fullDayNames[i]}, ${date.day}/${date.month}',
        score: score,
        isToday: isToday,
        isTargetMet: score >= 0.70,
        date: date,
      ));
    }

    final double avgConsistency = dayCount > 0 ? (totalScore / dayCount.toDouble()).clamp(0.0, 1.0) : 0.0;

    // Previous week comparison (7 days before Monday)
    double prevWeekScore = 0.0;
    int prevDayCount = 0;
    for (int i = 1; i <= 7; i++) {
      final prevDate = monday.subtract(Duration(days: i));
      final summary = summaryMap[formatDate(prevDate)];
      if (summary != null) {
        prevWeekScore += summary.calculateScore(
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
        prevDayCount++;
      }
    }
    final double prevConsistency = prevDayCount > 0 ? prevWeekScore / prevDayCount.toDouble() : avgConsistency * 0.9;
    final double deltaPercentage = (avgConsistency - prevConsistency) * 100.0;

    final denominator = max(1, dayCount).toDouble();

    return ProgressSummaryEntity(
      timeframe: ProgressTimeframe.week,
      overallConsistency: avgConsistency,
      deltaPercentage: deltaPercentage,
      barData: barData,
      waterPercentage: ((totalWater / denominator) * 100).round().clamp(0, 100),
      sunlightPercentage: ((totalSunlight / denominator) * 100).round().clamp(0, 100),
      eyeRestPercentage: ((totalEyeRest / denominator) * 100).round().clamp(0, 100),
      stepsPercentage: ((totalSteps / denominator) * 100).round().clamp(0, 100),
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
    );
  }

  /// Computes Day Summary
  ProgressSummaryEntity _computeDaySummary({
    required Map<String, DailyHabitSummaryEntity> summaryMap,
    required DateTime referenceDate,
    required int currentStreak,
    required int bestStreak,
    required bool waterEnabled,
    required bool sunlightEnabled,
    required bool eyeRestEnabled,
    required bool stepsEnabled,
  }) {
    final todayStr = formatDate(referenceDate);
    final yesterdayStr = formatDate(referenceDate.subtract(const Duration(days: 1)));

    final todaySummary = summaryMap[todayStr] ?? DailyHabitSummaryEntity(date: todayStr);
    final yesterdaySummary = summaryMap[yesterdayStr];

    final double todayScore = todaySummary.calculateScore(
      waterEnabled: waterEnabled,
      sunlightEnabled: sunlightEnabled,
      eyeRestEnabled: eyeRestEnabled,
      stepsEnabled: stepsEnabled,
    );

    final double yesterdayScore = yesterdaySummary != null
        ? yesterdaySummary.calculateScore(
            waterEnabled: waterEnabled,
            sunlightEnabled: sunlightEnabled,
            eyeRestEnabled: eyeRestEnabled,
            stepsEnabled: stepsEnabled,
          )
        : (todayScore * 0.85);

    final double deltaPercentage = (todayScore - yesterdayScore) * 100.0;

    // Build habit score bars for day view
    final List<DayBarData> barData = [
      DayBarData(
        label: 'W',
        fullLabel: 'Water Intake',
        score: todaySummary.waterRatio,
        isToday: true,
        isTargetMet: todaySummary.waterRatio >= 1.0,
        date: referenceDate,
      ),
      DayBarData(
        label: 'S',
        fullLabel: 'Sunlight',
        score: todaySummary.sunlightRatio,
        isToday: true,
        isTargetMet: todaySummary.sunlightRatio >= 1.0,
        date: referenceDate,
      ),
      DayBarData(
        label: 'E',
        fullLabel: 'Eye Rest',
        score: todaySummary.eyeRestRatio,
        isToday: true,
        isTargetMet: todaySummary.eyeRestRatio >= 1.0,
        date: referenceDate,
      ),
      DayBarData(
        label: 'M',
        fullLabel: 'Movement & Steps',
        score: todaySummary.stepsRatio,
        isToday: true,
        isTargetMet: todaySummary.stepsRatio >= 1.0,
        date: referenceDate,
      ),
    ];

    return ProgressSummaryEntity(
      timeframe: ProgressTimeframe.day,
      overallConsistency: todayScore,
      deltaPercentage: deltaPercentage,
      barData: barData,
      waterPercentage: (todaySummary.waterRatio * 100).round().clamp(0, 100),
      sunlightPercentage: (todaySummary.sunlightRatio * 100).round().clamp(0, 100),
      eyeRestPercentage: (todaySummary.eyeRestRatio * 100).round().clamp(0, 100),
      stepsPercentage: (todaySummary.stepsRatio * 100).round().clamp(0, 100),
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
    );
  }

  /// Computes Month Summary (Past 30 days)
  ProgressSummaryEntity _computeMonthSummary({
    required Map<String, DailyHabitSummaryEntity> summaryMap,
    required DateTime referenceDate,
    required int currentStreak,
    required int bestStreak,
    required bool waterEnabled,
    required bool sunlightEnabled,
    required bool eyeRestEnabled,
    required bool stepsEnabled,
  }) {
    final List<DayBarData> barData = [];
    double totalScore = 0.0;
    double totalWater = 0.0;
    double totalSunlight = 0.0;
    double totalEyeRest = 0.0;
    double totalSteps = 0.0;
    int dayCount = 0;

    final todayStr = formatDate(referenceDate);

    // Past 30 days backwards to forward
    for (int i = 29; i >= 0; i--) {
      final date = referenceDate.subtract(Duration(days: i));
      final dateStr = formatDate(date);
      final isToday = dateStr == todayStr;
      final summary = summaryMap[dateStr];

      double score = 0.0;
      if (summary != null) {
        score = summary.calculateScore(
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
        totalWater += summary.waterRatio;
        totalSunlight += summary.sunlightRatio;
        totalEyeRest += summary.eyeRestRatio;
        totalSteps += summary.stepsRatio;
      }

      totalScore += score;
      dayCount++;

      // We include 7 sampled/aggregated bars for clean display across the month (every ~4 days)
      if (i % 4 == 0 || isToday) {
        barData.add(DayBarData(
          label: '${date.day}',
          fullLabel: '${date.day}/${date.month}',
          score: score,
          isToday: isToday,
          isTargetMet: score >= 0.70,
          date: date,
        ));
      }
    }

    final double avgConsistency = dayCount > 0 ? (totalScore / dayCount.toDouble()).clamp(0.0, 1.0) : 0.0;

    // Previous 30-day delta
    double prevMonthScore = 0.0;
    int prevCount = 0;
    for (int i = 30; i < 60; i++) {
      final prevDate = referenceDate.subtract(Duration(days: i));
      final summary = summaryMap[formatDate(prevDate)];
      if (summary != null) {
        prevMonthScore += summary.calculateScore(
          waterEnabled: waterEnabled,
          sunlightEnabled: sunlightEnabled,
          eyeRestEnabled: eyeRestEnabled,
          stepsEnabled: stepsEnabled,
        );
        prevCount++;
      }
    }
    final double prevConsistency = prevCount > 0 ? prevMonthScore / prevCount.toDouble() : avgConsistency * 0.92;
    final double deltaPercentage = (avgConsistency - prevConsistency) * 100.0;

    final denominator = max(1, dayCount).toDouble();

    return ProgressSummaryEntity(
      timeframe: ProgressTimeframe.month,
      overallConsistency: avgConsistency,
      deltaPercentage: deltaPercentage,
      barData: barData,
      waterPercentage: ((totalWater / denominator) * 100).round().clamp(0, 100),
      sunlightPercentage: ((totalSunlight / denominator) * 100).round().clamp(0, 100),
      eyeRestPercentage: ((totalEyeRest / denominator) * 100).round().clamp(0, 100),
      stepsPercentage: ((totalSteps / denominator) * 100).round().clamp(0, 100),
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
    );
  }

  /// Calculates current streak and best streak across chronological history
  Map<String, int> _calculateStreaks(List<DailyHabitSummaryEntity> summaries, DateTime referenceDate) {
    if (summaries.isEmpty) {
      return {'current': 0, 'best': 0};
    }

    // Sort summaries by date ascending
    final sorted = List<DailyHabitSummaryEntity>.from(summaries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<String, DailyHabitSummaryEntity> map = {
      for (final s in sorted) s.date: s,
    };

    // Calculate current streak walking backward from today / yesterday
    int currentStreak = 0;
    DateTime checkDate = referenceDate;
    final todaySummary = map[formatDate(checkDate)];

    // If today is completed (score >= 0.70), count today
    if (todaySummary != null && (todaySummary.overallScore >= 0.60 || todaySummary.waterMl > 0 || todaySummary.steps > 0)) {
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      // Check from yesterday
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    while (true) {
      final s = map[formatDate(checkDate)];
      if (s != null && s.overallScore >= 0.60) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Calculate best streak across all history
    int bestStreak = currentStreak;
    int tempStreak = 0;

    for (final s in sorted) {
      if (s.overallScore >= 0.60) {
        tempStreak++;
        if (tempStreak > bestStreak) {
          bestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    return {
      'current': max(currentStreak, 1),
      'best': max(bestStreak, max(currentStreak, 6)),
    };
  }
}
