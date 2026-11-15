import 'dart:math';

import '../../../../core/services/system_screen_time_service.dart'
    show AppCumulativeUsage, AppSessionInterval;
import 'screen_activity_block.dart';

/// DailyRhythmEntity
///
/// Immutable domain model capturing today's device activity rhythm and Storyboard:
/// - List of Screen ON (Active Screen) and Screen OFF (Phone Rest) blocks with app breakdowns.
/// - Cumulative Active Screen Time and Phone Rest Time today.
/// - Number of gentle reminders delivered today.
/// - Current continuous screen session (keeps incrementing until meaningful rest is taken: 20m -> 40m).
/// - Configurable Continuous Screen Target (e.g. 20 min) and Required Rest Duration (e.g. 2 min).
/// - Timer Respect Rate & compliance stats.
/// - Cumulative app usage across the day with chronological intervals.
class DailyRhythmEntity {
  final List<ScreenActivityBlock> blocks;
  final List<AppCumulativeUsage> appUsages;
  final int activeScreenSeconds;
  final int phoneRestSeconds;
  final int remindersGiven;
  final int currentSessionSeconds;
  final int cycleTargetSeconds;
  final int requiredRestSeconds;
  final bool isScreenOn;
  final DateTime? screenOffSince;
  final bool isGentleReminderActive;
  final double timerRespectRate;
  final int promptRestsCount;
  final int ignoredRemindersCount;
  final String longestContinuousApp;
  final int longestContinuousSeconds;

  const DailyRhythmEntity({
    required this.blocks,
    this.appUsages = const [],
    required this.activeScreenSeconds,
    required this.phoneRestSeconds,
    required this.remindersGiven,
    required this.currentSessionSeconds,
    this.cycleTargetSeconds = 1200, // default 20 min
    this.requiredRestSeconds = 120, // default 2 min
    required this.isScreenOn,
    this.screenOffSince,
    this.isGentleReminderActive = false,
    this.timerRespectRate = 1.0,
    this.promptRestsCount = 0,
    this.ignoredRemindersCount = 0,
    this.longestContinuousApp = 'None',
    this.longestContinuousSeconds = 0,
  });

  factory DailyRhythmEntity.initial() {
    return const DailyRhythmEntity(
      blocks: [],
      appUsages: [],
      activeScreenSeconds: 0,
      phoneRestSeconds: 0,
      remindersGiven: 0,
      currentSessionSeconds: 0,
      cycleTargetSeconds: 1200,
      requiredRestSeconds: 120,
      isScreenOn: true,
      screenOffSince: null,
      isGentleReminderActive: false,
      timerRespectRate: 1.0,
      promptRestsCount: 0,
      ignoredRemindersCount: 0,
      longestContinuousApp: 'None',
      longestContinuousSeconds: 0,
    );
  }

  /// Returns native appUsages directly (authoritative from Android UsageStatsManager kernel events),
  /// or derives cumulative usage from recorded blocks as a resilient fallback.
  List<AppCumulativeUsage> get effectiveAppUsages {
    if (appUsages.isNotEmpty) {
      final list = List<AppCumulativeUsage>.from(appUsages);
      list.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
      return list;
    }
    return _deriveFromBlocks();
  }

  List<AppCumulativeUsage> _deriveFromBlocks() {
    final Map<String, int> durationMap = {};
    final Map<String, String> nameMap = {};
    final Map<String, List<AppSessionInterval>> intervalMap = {};

    for (final block in blocks) {
      if (!block.isActiveScreen) continue;
      for (final app in block.topApps) {
        if (app.package.isEmpty && app.name.isEmpty) continue;
        final key = app.package.isNotEmpty ? app.package : app.name;
        nameMap[key] = app.name.isNotEmpty ? app.name : key;
        final dur = app.seconds > 0 ? app.seconds : block.durationSeconds;
        durationMap[key] = (durationMap[key] ?? 0) + dur;
        intervalMap.putIfAbsent(key, () => []).add(
          AppSessionInterval(
            startTime: block.startTime,
            endTime: block.endTime,
            durationSeconds: dur,
          ),
        );
      }
    }

    return durationMap.entries.map((e) {
      return AppCumulativeUsage(
        name: nameMap[e.key] ?? e.key,
        package: e.key.contains('.') ? e.key : '',
        totalSeconds: e.value,
        intervals: intervalMap[e.key] ?? [],
      );
    }).toList();
  }

  /// Effective cycle session seconds (Option 1: Clean Cycle Reset).
  /// Resets cleanly to 00:00 when cycle target is reached or after meaningful rest.
  int get safeSessionSeconds {
    final effective = cycleTargetSeconds > 0
        ? currentSessionSeconds % cycleTargetSeconds
        : currentSessionSeconds;
    return max(0, effective);
  }

  /// Progress fraction towards the current cycle milestone (0.0 to 1.0).
  double get sessionProgress {
    if (cycleTargetSeconds <= 0) return 0.0;
    final sec = safeSessionSeconds;
    return (sec / cycleTargetSeconds).clamp(0.0, 1.0);
  }

  /// Progress multiplier against target (0.0 to 1.0 in clean cycle)
  double get continuousMultiplier {
    if (cycleTargetSeconds <= 0) return 1.0;
    return safeSessionSeconds / cycleTargetSeconds;
  }

  bool get isOverrun => false;

  /// Formatted Active Screen time: "Xh Ym" or "Y min" (rounds to nearest minute)
  String get activeScreenFormatted {
    if (activeScreenSeconds < 60) return '${activeScreenSeconds}s';
    final m = (activeScreenSeconds + 30) ~/ 60;
    final h = m ~/ 60;
    final remM = m % 60;
    if (h == 0) return '$remM min';
    return '${h}h ${remM}m';
  }

  /// Formatted Phone Rest time: "Ah Bm" or "B min" (rounds to nearest minute)
  String get phoneRestFormatted {
    if (phoneRestSeconds < 60) return '${phoneRestSeconds}s';
    final m = (phoneRestSeconds + 30) ~/ 60;
    final h = m ~/ 60;
    final remM = m % 60;
    if (h == 0) return '$remM min';
    return '${h}h ${remM}m';
  }

  /// Formats current continuous session in mm:ss or Hh Mm
  String get sessionFormatted {
    final sec = safeSessionSeconds;
    if (sec >= 3600) {
      final h = sec ~/ 3600;
      final m = (sec % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
    final mins = sec ~/ 60;
    final secs = sec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int get totalAlertsCount =>
      max(remindersGiven, promptRestsCount + ignoredRemindersCount);

  /// Shows timer respect as an honest COUNT instead of an abstract percentage:
  /// e.g. "3 / 4" (3 of 4 prompts responded within 5-10s) or "0 / 0"
  String get timerRespectFormatted {
    if (totalAlertsCount == 0 && promptRestsCount == 0) {
      return '0 / 0';
    }
    return '$promptRestsCount / $totalAlertsCount';
  }

  String get timerRespectPercentageFormatted =>
      '${(timerRespectRate * 100).round()}%';

  DailyRhythmEntity copyWith({
    List<ScreenActivityBlock>? blocks,
    List<AppCumulativeUsage>? appUsages,
    int? activeScreenSeconds,
    int? phoneRestSeconds,
    int? remindersGiven,
    int? currentSessionSeconds,
    int? cycleTargetSeconds,
    int? requiredRestSeconds,
    bool? isScreenOn,
    DateTime? screenOffSince,
    bool clearScreenOffSince = false,
    bool? isGentleReminderActive,
    double? timerRespectRate,
    int? promptRestsCount,
    int? ignoredRemindersCount,
    String? longestContinuousApp,
    int? longestContinuousSeconds,
  }) {
    return DailyRhythmEntity(
      blocks: blocks ?? this.blocks,
      appUsages: appUsages ?? this.appUsages,
      activeScreenSeconds: activeScreenSeconds ?? this.activeScreenSeconds,
      phoneRestSeconds: phoneRestSeconds ?? this.phoneRestSeconds,
      remindersGiven: remindersGiven ?? this.remindersGiven,
      currentSessionSeconds:
          currentSessionSeconds ?? this.currentSessionSeconds,
      cycleTargetSeconds: cycleTargetSeconds ?? this.cycleTargetSeconds,
      requiredRestSeconds: requiredRestSeconds ?? this.requiredRestSeconds,
      isScreenOn: isScreenOn ?? this.isScreenOn,
      screenOffSince: clearScreenOffSince
          ? null
          : (screenOffSince ?? this.screenOffSince),
      isGentleReminderActive:
          isGentleReminderActive ?? this.isGentleReminderActive,
      timerRespectRate: timerRespectRate ?? this.timerRespectRate,
      promptRestsCount: promptRestsCount ?? this.promptRestsCount,
      ignoredRemindersCount:
          ignoredRemindersCount ?? this.ignoredRemindersCount,
      longestContinuousApp: longestContinuousApp ?? this.longestContinuousApp,
      longestContinuousSeconds:
          longestContinuousSeconds ?? this.longestContinuousSeconds,
    );
  }
}
