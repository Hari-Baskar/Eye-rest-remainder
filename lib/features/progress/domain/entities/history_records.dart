import 'package:reset/features/progress/presentation/widgets/daily_history_tile.dart';

import '../../../../core/database/app_database.dart';
import '../../../eye_rest/domain/entities/daily_rhythm_entity.dart';
import '../../../eye_rest/domain/entities/screen_activity_block.dart';

import 'strain_session_detail.dart';

/// DailyHistoryRecord
///
/// Clean, unopinionated record of a single day's screen time, rest, and longest strain.
class DailyHistoryRecord {
  final String dateStr; // 'YYYY-MM-DD'
  final DateTime date;
  final String title; // 'Today', 'Yesterday', or 'Monday'
  final String subdate; // 'Nov 11'
  final int phoneSeconds;
  final int restSeconds;
  final int alertsCount;
  final StrainSessionDetail? longestStrain;
  final List<AppUsageSnippet> topApps;

  const DailyHistoryRecord({
    required this.dateStr,
    required this.date,
    required this.title,
    required this.subdate,
    required this.phoneSeconds,
    required this.restSeconds,
    this.alertsCount = 0,
    this.longestStrain,
    this.topApps = const [],
  });
}

/// WeeklyHistoryRecord
///
/// Clean rollup of a week's total time, daily averages, peak strain, and app usage.
class WeeklyHistoryRecord {
  final String id; // '2026-W45'
  final String title; // 'This Week' or 'Last Week' or 'Week 43'
  final String dateRangeStr; // 'Nov 5 – Nov 11'
  final DateTime startOfWeek;
  final DateTime endOfWeek;
  final int totalPhoneSeconds;
  final int totalRestSeconds;
  final int recordedDaysCount;
  final int alertsCount;
  final StrainSessionDetail? peakStrain;
  final List<DailyHistoryRecord> days;
  final List<AppUsageSnippet> topApps;

  const WeeklyHistoryRecord({
    required this.id,
    required this.title,
    required this.dateRangeStr,
    required this.startOfWeek,
    required this.endOfWeek,
    required this.totalPhoneSeconds,
    required this.totalRestSeconds,
    required this.recordedDaysCount,
    this.alertsCount = 0,
    this.peakStrain,
    required this.days,
    this.topApps = const [],
  });

  int get avgPhoneSecondsPerDay =>
      recordedDaysCount > 0 ? totalPhoneSeconds ~/ recordedDaysCount : 0;
  int get avgRestSecondsPerDay =>
      recordedDaysCount > 0 ? totalRestSeconds ~/ recordedDaysCount : 0;
}

/// MonthlyHistoryRecord
///
/// Clean rollup of a calendar month's total time, daily averages, peak strain, and app usage.
class MonthlyHistoryRecord {
  final String id; // '2026-11'
  final String title; // 'November 2026'
  final String subdate; // 'Current · 11 days' or 'Full month · 31 days'
  final DateTime monthStart;
  final int totalPhoneSeconds;
  final int totalRestSeconds;
  final int recordedDaysCount;
  final int alertsCount;
  final StrainSessionDetail? peakStrain;
  final List<WeeklyHistoryRecord> weeks;
  final List<DailyHistoryRecord> days;
  final List<AppUsageSnippet> topApps;

  const MonthlyHistoryRecord({
    required this.id,
    required this.title,
    required this.subdate,
    required this.monthStart,
    required this.totalPhoneSeconds,
    required this.totalRestSeconds,
    required this.recordedDaysCount,
    this.alertsCount = 0,
    this.peakStrain,
    required this.weeks,
    this.days = const [],
    this.topApps = const [],
  });

  int get avgPhoneSecondsPerDay =>
      recordedDaysCount > 0 ? totalPhoneSeconds ~/ recordedDaysCount : 0;
  int get avgRestSecondsPerDay =>
      recordedDaysCount > 0 ? totalRestSeconds ~/ recordedDaysCount : 0;
}

/// HistoryAggregator
///
/// Converts raw SQLite daily records into structured Daily, Weekly, and Monthly records.
class HistoryAggregator {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _fullMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static Map<String, dynamic> buildHistory({
    required AppDatabase db,
    required DailyRhythmEntity currentRhythm,
  }) {
    final now = DateTime.now();
    final todayStr = DailyHistoryHelper.formatIsoDate(now);
    final yesterdayStr = DailyHistoryHelper.formatIsoDate(
      now.subtract(const Duration(days: 1)),
    );
    final installDateStr = db.getInstallDate();

    final rawSummaries = db.getAllDailySummariesDesc();
    final Map<String, dynamic> dateMap = {};

    for (final s in rawSummaries) {
      if (s.date.compareTo(installDateStr) >= 0) {
        dateMap[s.date] = s;
      }
    }

    // Include all dates that have recorded activity blocks in SQLite (>= installDate)
    for (final dStr in db.getDistinctActivityBlockDates()) {
      if (dStr.compareTo(installDateStr) >= 0) {
        dateMap.putIfAbsent(dStr, () => null);
      }
    }

    // Always ensure today exists
    dateMap.putIfAbsent(todayStr, () => null);
    // Only include yesterday if on or after install date
    if (yesterdayStr.compareTo(installDateStr) >= 0) {
      dateMap.putIfAbsent(yesterdayStr, () => null);
    }

    final sortedDates = dateMap.keys.toList()..sort((a, b) => b.compareTo(a));

    final dailyList = <DailyHistoryRecord>[];

    for (final dateStr in sortedDates) {
      final parsed = DateTime.tryParse(dateStr) ?? now;
      final isToday = dateStr == todayStr;
      final isYesterday = dateStr == yesterdayStr;

      List<ScreenActivityBlock> blocks;
      int phoneSec = 0;
      int restSec = 0;

      if (isToday) {
        blocks = currentRhythm.blocks.isNotEmpty
            ? currentRhythm.blocks
            : db.getActivityBlocksForDate(parsed);
        phoneSec = currentRhythm.activeScreenSeconds;
        restSec = currentRhythm.phoneRestSeconds;
      } else {
        blocks = db.getActivityBlocksForDate(parsed);
        for (final b in blocks) {
          if (b.isActiveScreen) {
            phoneSec += b.durationSeconds;
          } else {
            restSec += b.durationSeconds;
          }
        }
        final summary = dateMap[dateStr];
        if (summary != null && summary.screenTimeSeconds > phoneSec) {
          phoneSec = summary.screenTimeSeconds;
        }
      }

      // Calculate longest continuous strain session using user's custom required rest duration
      final longestStrain = StrainSessionDetail.calculateLongestStrain(
        blocks,
        minRestThresholdSeconds: currentRhythm.requiredRestSeconds,
      );

      // Collect top apps for this day
      final Map<String, AppUsageSnippet> dayAppMap = {};
      for (final b in blocks) {
        if (!b.isActiveScreen) continue;
        for (final app in b.topApps) {
          final lowerName = app.name.toLowerCase().trim();
          final lowerPkg = app.package.toLowerCase().trim();
          if (lowerName == 'home screen' ||
              lowerName == 'screen active' ||
              lowerName.isEmpty) {
            continue;
          }
          final existing = dayAppMap[app.name];
          if (existing != null) {
            dayAppMap[app.name] = AppUsageSnippet(
              name: app.name,
              package: app.package.isNotEmpty ? app.package : existing.package,
              seconds: existing.seconds + app.seconds,
            );
          } else {
            dayAppMap[app.name] = app;
          }
        }
      }

      final dayApps = dayAppMap.values.toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));

      String title;
      String subdate;
      if (isToday) {
        title = 'Today';
        subdate = '${_months[parsed.month - 1]} ${parsed.day}';
      } else if (isYesterday) {
        title = 'Yesterday';
        subdate = '${_months[parsed.month - 1]} ${parsed.day}';
      } else {
        const weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        title = weekdays[parsed.weekday - 1];
        subdate = '${_months[parsed.month - 1]} ${parsed.day}';
      }

      final alertsCount = db.getGentleReminderTimestampsForDate(parsed).length;

      dailyList.add(
        DailyHistoryRecord(
          dateStr: dateStr,
          date: parsed,
          title: title,
          subdate: subdate,
          phoneSeconds: phoneSec,
          restSeconds: restSec,
          alertsCount: alertsCount,
          longestStrain: longestStrain,
          topApps: dayApps,
        ),
      );
    }

    // 2. Build Weekly Records (Rolling 7-day or ISO week grouping)
    final weeklyList = _groupIntoWeeks(dailyList, now);

    // 3. Build Monthly Records (Grouped by YYYY-MM)
    final monthlyList = _groupIntoMonths(dailyList, weeklyList, now);

    return {'daily': dailyList, 'weekly': weeklyList, 'monthly': monthlyList};
  }

  static List<WeeklyHistoryRecord> _groupIntoWeeks(
    List<DailyHistoryRecord> days,
    DateTime now,
  ) {
    if (days.isEmpty) return [];

    final Map<String, List<DailyHistoryRecord>> weekMap = {};
    for (final day in days) {
      // Find start of week (Monday)
      final dt = day.date;
      final monday = dt.subtract(Duration(days: dt.weekday - 1));
      final weekKey =
          '${monday.year}-W${_getWeekOfYear(monday).toString().padLeft(2, '0')}';
      weekMap.putIfAbsent(weekKey, () => []).add(day);
    }

    final sortedWeekKeys = weekMap.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekKey =
        '${currentMonday.year}-W${_getWeekOfYear(currentMonday).toString().padLeft(2, '0')}';

    final lastWeekMonday = currentMonday.subtract(const Duration(days: 7));
    final lastWeekKey =
        '${lastWeekMonday.year}-W${_getWeekOfYear(lastWeekMonday).toString().padLeft(2, '0')}';

    final result = <WeeklyHistoryRecord>[];

    for (final key in sortedWeekKeys) {
      final daysInWeek = weekMap[key]!;
      daysInWeek.sort((a, b) => b.date.compareTo(a.date));

      final firstDay = daysInWeek.last.date;
      final monday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      String title;
      if (key == currentWeekKey) {
        title = 'This Week';
      } else if (key == lastWeekKey) {
        title = 'Last Week';
      } else {
        title = 'Week ${_getWeekOfYear(monday)}';
      }

      final dateRangeStr =
          '${_months[monday.month - 1]} ${monday.day} – ${_months[sunday.month - 1]} ${sunday.day}';

      int totalPhone = 0;
      int totalRest = 0;
      int totalAlerts = 0;
      StrainSessionDetail? peakStrain;
      final Map<String, AppUsageSnippet> appAgg = {};

      for (final d in daysInWeek) {
        totalPhone += d.phoneSeconds;
        totalRest += d.restSeconds;
        totalAlerts += d.alertsCount;
        if (d.longestStrain != null) {
          if (peakStrain == null ||
              d.longestStrain!.durationSeconds > peakStrain.durationSeconds) {
            peakStrain = d.longestStrain;
          }
        }
        for (final app in d.topApps) {
          final existing = appAgg[app.name];
          if (existing != null) {
            appAgg[app.name] = AppUsageSnippet(
              name: app.name,
              package: app.package.isNotEmpty ? app.package : existing.package,
              seconds: existing.seconds + app.seconds,
            );
          } else {
            appAgg[app.name] = app;
          }
        }
      }

      final sortedApps = appAgg.values.toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));

      result.add(
        WeeklyHistoryRecord(
          id: key,
          title: title,
          dateRangeStr: dateRangeStr,
          startOfWeek: monday,
          endOfWeek: sunday,
          totalPhoneSeconds: totalPhone,
          totalRestSeconds: totalRest,
          recordedDaysCount: daysInWeek.length,
          alertsCount: totalAlerts,
          peakStrain: peakStrain,
          days: daysInWeek,
          topApps: sortedApps,
        ),
      );
    }

    return result;
  }

  static List<MonthlyHistoryRecord> _groupIntoMonths(
    List<DailyHistoryRecord> days,
    List<WeeklyHistoryRecord> weeks,
    DateTime now,
  ) {
    if (days.isEmpty) return [];

    final Map<String, List<DailyHistoryRecord>> monthMap = {};
    for (final day in days) {
      final key =
          '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}';
      monthMap.putIfAbsent(key, () => []).add(day);
    }

    final sortedMonthKeys = monthMap.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final result = <MonthlyHistoryRecord>[];

    for (final key in sortedMonthKeys) {
      final daysInMonth = monthMap[key]!;
      daysInMonth.sort((a, b) => b.date.compareTo(a.date));

      final firstDate = daysInMonth.first.date;
      final monthName = _fullMonths[firstDate.month - 1];
      final title = '$monthName ${firstDate.year}';

      final isCurrent = key == currentMonthKey;
      final subdate = isCurrent
          ? 'Current · ${daysInMonth.length} days'
          : '${daysInMonth.length} days recorded';

      int totalPhone = 0;
      int totalRest = 0;
      int totalAlerts = 0;
      StrainSessionDetail? peakStrain;
      final Map<String, AppUsageSnippet> appAgg = {};

      for (final d in daysInMonth) {
        totalPhone += d.phoneSeconds;
        totalRest += d.restSeconds;
        totalAlerts += d.alertsCount;
        if (d.longestStrain != null) {
          if (peakStrain == null ||
              d.longestStrain!.durationSeconds > peakStrain.durationSeconds) {
            peakStrain = d.longestStrain;
          }
        }
        for (final app in d.topApps) {
          final existing = appAgg[app.name];
          if (existing != null) {
            appAgg[app.name] = AppUsageSnippet(
              name: app.name,
              package: app.package.isNotEmpty ? app.package : existing.package,
              seconds: existing.seconds + app.seconds,
            );
          } else {
            appAgg[app.name] = app;
          }
        }
      }

      final sortedApps = appAgg.values.toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));

      // Filter weeks belonging to this month
      final monthWeeks = weeks.where((w) {
        return (w.startOfWeek.year == firstDate.year &&
                w.startOfWeek.month == firstDate.month) ||
            (w.endOfWeek.year == firstDate.year &&
                w.endOfWeek.month == firstDate.month);
      }).toList();

      result.add(
        MonthlyHistoryRecord(
          id: key,
          title: title,
          subdate: subdate,
          monthStart: DateTime(firstDate.year, firstDate.month, 1),
          totalPhoneSeconds: totalPhone,
          totalRestSeconds: totalRest,
          recordedDaysCount: daysInMonth.length,
          alertsCount: totalAlerts,
          peakStrain: peakStrain,
          weeks: monthWeeks,
          days: daysInMonth,
          topApps: sortedApps,
        ),
      );
    }

    return result;
  }

  static int _getWeekOfYear(DateTime dt) {
    final firstDayOfYear = DateTime(dt.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - 1;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    return (dt.difference(firstMonday).inDays ~/ 7) + 1;
  }
}
