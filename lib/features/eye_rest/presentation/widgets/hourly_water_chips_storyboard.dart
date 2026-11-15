import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/daily_rhythm_entity.dart';
import '../../domain/entities/screen_activity_block.dart';
import 'app_icon_badge.dart';

/// HourTimelineEvent
///
/// Sealed base class for chronological timeline events.
sealed class HourTimelineEvent {
  DateTime get timestamp;
}

/// AppUsageTimelineEvent
///
/// An app usage interval within the hour (e.g. 8:09 to 8:15 Chrome • 6m).
class AppUsageTimelineEvent extends HourTimelineEvent {
  final String name;
  final String package;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String note;
  final DateTime? alertTriggerTime;
  final String? stopAction;
  final int? restAfterSeconds;

  AppUsageTimelineEvent({
    required this.name,
    required this.package,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.note = '',
    this.alertTriggerTime,
    this.stopAction,
    this.restAfterSeconds,
  });

  AppUsageTimelineEvent copyWith({
    String? name,
    String? package,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? note,
    DateTime? alertTriggerTime,
    String? stopAction,
    int? restAfterSeconds,
  }) {
    return AppUsageTimelineEvent(
      name: name ?? this.name,
      package: package ?? this.package,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      note: note ?? this.note,
      alertTriggerTime: alertTriggerTime ?? this.alertTriggerTime,
      stopAction: stopAction ?? this.stopAction,
      restAfterSeconds: restAfterSeconds ?? this.restAfterSeconds,
    );
  }

  @override
  DateTime get timestamp => startTime;

  int get durationMinutes => max(1, (durationSeconds / 60).round());

  String get formattedDuration =>
      HourlyWaterChipsStoryboard.formatDurationWithSeconds(durationSeconds);

  String get extraAfterAlertFormatted => '';
}

/// RestTimelineEvent
///
/// A screen OFF / phone rest period (e.g. 8:15:20 to 8:17:35 Phone Rest • 2m 15s).
class RestTimelineEvent extends HourTimelineEvent {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String note;
  final bool wasAfterAlert;

  RestTimelineEvent({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.note = '',
    this.wasAfterAlert = false,
  });

  RestTimelineEvent copyWith({
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? note,
    bool? wasAfterAlert,
  }) {
    return RestTimelineEvent(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      note: note ?? this.note,
      wasAfterAlert: wasAfterAlert ?? this.wasAfterAlert,
    );
  }

  @override
  DateTime get timestamp => startTime;

  int get durationMinutes => max(1, (durationSeconds / 60).round());

  String get formattedDuration =>
      HourlyWaterChipsStoryboard.formatDurationWithSeconds(durationSeconds);
}

/// AlertTimelineEvent
///
/// A genuine eye break alert milestone fired at a specific time (e.g. 8:15:20 PM Alert Triggered).
class AlertTimelineEvent extends HourTimelineEvent {
  final DateTime alertTime;
  final String text;
  final String? stopExplanation;

  AlertTimelineEvent({
    required this.alertTime,
    required this.text,
    this.stopExplanation,
  });

  AlertTimelineEvent copyWith({
    DateTime? alertTime,
    String? text,
    String? stopExplanation,
  }) {
    return AlertTimelineEvent(
      alertTime: alertTime ?? this.alertTime,
      text: text ?? this.text,
      stopExplanation: stopExplanation ?? this.stopExplanation,
    );
  }

  @override
  DateTime get timestamp => alertTime;
}

/// AppSummaryChip
///
/// Summary chip for an application used in this hour with its cumulative minutes.
class AppSummaryChip {
  final String name;
  final String package;
  final int totalSeconds;

  AppSummaryChip({
    required this.name,
    required this.package,
    required this.totalSeconds,
  });

  int get totalMinutes => max(1, (totalSeconds / 60).round());

  String get formattedDuration =>
      HourlyWaterChipsStoryboard.formatDurationWithSeconds(totalSeconds);
}

/// HourSliceData
///
/// Encapsulates the chronological flow of a single clock hour (0 to 23).
/// Distinguishes elapsed from upcoming time and holds cute app summary chips.
class HourSliceData {
  final int hour; // 0 to 23
  final String label; // "12a", "1p", etc.
  final DateTime windowStart;
  final DateTime windowEnd;
  final int usedSeconds;
  final int restSeconds;
  final int elapsedSeconds;
  final bool isCurrentHour;
  final bool hasAlert;
  final List<AppSummaryChip> apps;
  final List<HourTimelineEvent> events;
  final bool isFuture;

  const HourSliceData({
    required this.hour,
    required this.label,
    required this.windowStart,
    required this.windowEnd,
    required this.usedSeconds,
    required this.restSeconds,
    required this.elapsedSeconds,
    this.isCurrentHour = false,
    this.hasAlert = false,
    this.apps = const [],
    this.events = const [],
    this.isFuture = false,
  });

  int get usedMinutes => (usedSeconds / 60).round().clamp(0, 60);
  int get restMinutes => (restSeconds / 60).round().clamp(0, 60);
  int get elapsedMinutes => (elapsedSeconds / 60).round().clamp(0, 60);
  int get remainingMinutes => (60 - elapsedMinutes).clamp(0, 60);

  String get displayTimeRange {
    final startStr = _formatHour(hour);
    final endH = (hour + 1) % 24;
    final endStr = _formatHour(endH);
    return '$startStr → $endStr';
  }

  static String _formatHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:00 $period';
  }

  static String _formatHourWithAmPm(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH $period';
  }

  static String _shortLabel(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH $period';
  }
}

/// HourlyWaterChipsStoryboard
///
/// Minimal Cute Chips Storyboard:
/// 1. Top of Hour: Shows cute pill chips for all apps used in that hour with minutes.
/// 2. Chronological Timeline below: Step-by-step cute chips showing exact intervals
///    (e.g. 8:09–8:15 Chrome, 8:15 Alert, then Rest Period or next App used).
/// 3. Accurate Elapsed Time: Current hour at 8:32 PM only counts 32m elapsed (26m used, 6m rested).
class HourlyWaterChipsStoryboard extends StatefulWidget {
  final DailyRhythmEntity rhythm;
  final List<ScreenActivityBlock> blocks;
  final DateTime date;
  final bool isToday;
  final List<DateTime> alertTimestamps;
  final bool isDark;
  final Color slateColor;
  final Color mintColor;
  final Color blueColor;
  final Color amberColor;
  final Color dividerColor;
  final String? selectedAppPackage;
  final ValueChanged<String?>? onAppSelected;
  final int? selectedHour;
  final ValueChanged<int>? onHourSelected;

  const HourlyWaterChipsStoryboard({
    super.key,
    required this.rhythm,
    required this.blocks,
    required this.date,
    required this.isToday,
    this.alertTimestamps = const [],
    required this.isDark,
    required this.slateColor,
    required this.mintColor,
    required this.blueColor,
    required this.amberColor,
    required this.dividerColor,
    this.selectedAppPackage,
    this.onAppSelected,
    this.selectedHour,
    this.onHourSelected,
  });

  static String formatTimeWithSeconds(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:$m:$s $period';
  }

  static String formatDurationWithSeconds(int totalSec) {
    if (totalSec < 60) {
      return '${totalSec}s';
    }
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  @override
  State<HourlyWaterChipsStoryboard> createState() =>
      _HourlyWaterChipsStoryboardState();
}

class _HourlyWaterChipsStoryboardState
    extends State<HourlyWaterChipsStoryboard> {
  int _selectedHour = 12;
  late List<HourSliceData> _hours;
  bool _showMinuteDetails = false;

  @override
  void initState() {
    super.initState();
    _buildHours();
    if (widget.selectedHour != null) {
      _selectedHour = widget.selectedHour!.clamp(0, 23);
    } else if (widget.isToday) {
      _selectedHour = DateTime.now().hour.clamp(0, 23);
    } else {
      int bestHour = 12;
      int maxUsed = -1;
      for (final h in _hours) {
        if (h.usedSeconds > maxUsed) {
          maxUsed = h.usedSeconds;
          bestHour = h.hour;
        }
      }
      _selectedHour = bestHour;
    }
  }

  @override
  void didUpdateWidget(HourlyWaterChipsStoryboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedHour != null &&
        widget.selectedHour != oldWidget.selectedHour) {
      _selectedHour = widget.selectedHour!.clamp(0, 23);
    }
    if (oldWidget.blocks != widget.blocks ||
        oldWidget.alertTimestamps != widget.alertTimestamps ||
        oldWidget.date != widget.date) {
      _buildHours();
    }
    // Auto-jump to the top hour of the newly selected app
    if (widget.selectedAppPackage != null &&
        widget.selectedAppPackage != oldWidget.selectedAppPackage) {
      _autoJumpToSelectedAppHour(widget.selectedAppPackage!);
    }
  }

  void _autoJumpToSelectedAppHour(String pkg) {
    int bestHour = -1;
    int maxSec = -1;
    final lowerPkg = pkg.toLowerCase();

    for (final h in _hours) {
      for (final a in h.apps) {
        if (a.package == pkg ||
            a.package.toLowerCase() == lowerPkg ||
            a.name.toLowerCase() == lowerPkg) {
          if (a.totalSeconds > maxSec) {
            maxSec = a.totalSeconds;
            bestHour = h.hour;
          }
        }
      }
    }

    // Fallback: check timeline events if not in apps summary
    if (bestHour < 0) {
      for (final h in _hours) {
        for (final ev in h.events.whereType<AppUsageTimelineEvent>()) {
          if (ev.package == pkg ||
              ev.package.toLowerCase() == lowerPkg ||
              ev.name.toLowerCase() == lowerPkg) {
            bestHour = h.hour;
            break;
          }
        }
        if (bestHour >= 0) break;
      }
    }

    if (bestHour >= 0 && bestHour != _selectedHour) {
      setState(() {
        _selectedHour = bestHour;
      });
    }
  }

  bool _isTargetApp(String pkg, String name) {
    if (widget.selectedAppPackage == null ||
        widget.selectedAppPackage!.isEmpty) {
      return false;
    }
    final target = widget.selectedAppPackage!.toLowerCase();
    return pkg == widget.selectedAppPackage ||
        pkg.toLowerCase() == target ||
        name.toLowerCase() == target;
  }

  bool _hourMatchesSelectedApp(HourSliceData data) {
    if (widget.selectedAppPackage == null ||
        widget.selectedAppPackage!.isEmpty) {
      return false;
    }
    final target = widget.selectedAppPackage!.toLowerCase();
    final inApps = data.apps.any(
      (a) =>
          a.package == widget.selectedAppPackage ||
          a.package.toLowerCase() == target ||
          a.name.toLowerCase() == target,
    );
    if (inApps) return true;

    return data.events.whereType<AppUsageTimelineEvent>().any(
      (ev) =>
          ev.package == widget.selectedAppPackage ||
          ev.package.toLowerCase() == target ||
          ev.name.toLowerCase() == target,
    );
  }

  int _getSelectedAppSecondsInHour(HourSliceData data) {
    if (widget.selectedAppPackage == null ||
        widget.selectedAppPackage!.isEmpty) {
      return 0;
    }
    for (final a in data.apps) {
      if (_isTargetApp(a.package, a.name)) {
        return a.totalSeconds;
      }
    }
    int total = 0;
    for (final ev in data.events.whereType<AppUsageTimelineEvent>()) {
      if (_isTargetApp(ev.package, ev.name)) {
        total += ev.durationSeconds;
      }
    }
    return total;
  }

  int _getSelectedAppMinutesInHour(HourSliceData data) {
    final sec = _getSelectedAppSecondsInHour(data);
    if (sec <= 0) return 0;
    return max(1, (sec / 60).round());
  }

  String _getSelectedAppFormattedDuration(HourSliceData data) {
    final sec = _getSelectedAppSecondsInHour(data);
    return HourlyWaterChipsStoryboard.formatDurationWithSeconds(sec);
  }

  List<AppUsageTimelineEvent> _extractAppIntervals({
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required ScreenActivityBlock block,
  }) {
    final list = <AppUsageTimelineEvent>[];

    // Method 1: Exact native app intervals
    for (final app in widget.rhythm.effectiveAppUsages) {
      for (final interval in app.intervals) {
        if (interval.endTime.isAfter(sessionStart) &&
            interval.startTime.isBefore(sessionEnd)) {
          final clippedStart = interval.startTime.isBefore(sessionStart)
              ? sessionStart
              : interval.startTime;
          final clippedEnd = interval.endTime.isAfter(sessionEnd)
              ? sessionEnd
              : interval.endTime;
          final durSec = clippedEnd.difference(clippedStart).inSeconds;
          if (durSec >= 3) {
            list.add(
              AppUsageTimelineEvent(
                name: app.name,
                package: app.package,
                startTime: clippedStart,
                endTime: clippedEnd,
                durationSeconds: durSec,
              ),
            );
          }
        }
      }
    }

    if (list.isNotEmpty) {
      list.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Ensure every minute of this active session is accounted for
      final filledList = <AppUsageTimelineEvent>[];
      DateTime cur = sessionStart;

      for (final ev in list) {
        if (ev.startTime.isAfter(cur)) {
          final gapSec = ev.startTime.difference(cur).inSeconds;
          if (gapSec >= 5) {
            filledList.add(
              AppUsageTimelineEvent(
                name: 'Screen Active',
                package: '',
                startTime: cur,
                endTime: ev.startTime,
                durationSeconds: gapSec,
              ),
            );
          }
        }
        filledList.add(ev);
        if (ev.endTime.isAfter(cur)) {
          cur = ev.endTime;
        }
      }

      if (sessionEnd.isAfter(cur)) {
        final gapSec = sessionEnd.difference(cur).inSeconds;
        if (gapSec >= 5) {
          final isRightNow = DateTime.now().difference(sessionEnd).inSeconds.abs() < 60;
          filledList.add(
            AppUsageTimelineEvent(
              name: isRightNow ? 'LifeMint' : 'Screen Active',
              package: isRightNow ? 'com.reset' : '',
              startTime: cur,
              endTime: sessionEnd,
              durationSeconds: gapSec,
            ),
          );
        }
      }

      return filledList;
    }

    // Method 2: Sequential fallback using block.topApps
    if (block.topApps.isNotEmpty) {
      DateTime appCursor = sessionStart;
      final totalSnippetSec = block.topApps.fold<int>(
        0,
        (sum, a) => sum + a.seconds,
      );
      final sessionDurSec = sessionEnd.difference(sessionStart).inSeconds;

      for (int i = 0; i < block.topApps.length; i++) {
        final app = block.topApps[i];
        if (app.seconds <= 0) continue;

        final durSec = totalSnippetSec > 0
            ? ((app.seconds / totalSnippetSec) * sessionDurSec).round()
            : (sessionDurSec ~/ block.topApps.length);

        if (durSec <= 0) continue;

        var appEnd = appCursor.add(Duration(seconds: durSec));
        if (i == block.topApps.length - 1 || appEnd.isAfter(sessionEnd)) {
          appEnd = sessionEnd;
        }

        if (appEnd.isAfter(appCursor)) {
          list.add(
            AppUsageTimelineEvent(
              name: app.name.isEmpty ? 'Screen Active' : app.name,
              package: app.package,
              startTime: appCursor,
              endTime: appEnd,
              durationSeconds: appEnd.difference(appCursor).inSeconds,
            ),
          );
          appCursor = appEnd;
        }
        if (!appCursor.isBefore(sessionEnd)) break;
      }
      return list;
    }

    // Method 3: Resilient fallback
    final isRightNow = DateTime.now().difference(sessionEnd).inSeconds.abs() < 60;
    list.add(
      AppUsageTimelineEvent(
        name: isRightNow ? 'LifeMint' : 'Screen Active',
        package: isRightNow ? 'com.reset' : '',
        startTime: sessionStart,
        endTime: sessionEnd,
        durationSeconds: sessionEnd.difference(sessionStart).inSeconds,
      ),
    );
    return list;
  }

  void _buildHours() {
    final now = DateTime.now();
    final isCurrentDay = widget.isToday;
    final currentHour = now.hour;

    final result = <HourSliceData>[];

    for (int h = 0; h < 24; h++) {
      final isFuture = isCurrentDay && h > currentHour;
      final isCurrentHour = isCurrentDay && h == currentHour;

      final winStart = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        h,
        0,
        0,
      );
      final winEnd = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        h,
        59,
        59,
        999,
      );

      if (isFuture) {
        result.add(
          HourSliceData(
            hour: h,
            label: HourSliceData._shortLabel(h),
            windowStart: winStart,
            windowEnd: winEnd,
            usedSeconds: 0,
            restSeconds: 0,
            elapsedSeconds: 0,
            isCurrentHour: false,
            isFuture: true,
          ),
        );
        continue;
      }

      // Effective end of time observed so far:
      final effectiveEnd = isCurrentHour
          ? (now.isBefore(winEnd) ? now : winEnd)
          : winEnd;

      final elapsedSeconds = effectiveEnd
          .difference(winStart)
          .inSeconds
          .clamp(0, 3600);

      // Collect overlapping blocks for this hour up to effectiveEnd
      final hourBlocks = widget.blocks.where((b) {
        return !b.endTime.isBefore(winStart) &&
            !b.startTime.isAfter(effectiveEnd);
      }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

      // Build chronological events for this hour
      final chronologicalEvents = <HourTimelineEvent>[];
      int usedSec = 0;

      DateTime cursor = winStart;

      for (final b in hourBlocks) {
        final effStart = b.startTime.isBefore(winStart)
            ? winStart
            : b.startTime;
        final effEnd = b.endTime.isAfter(effectiveEnd)
            ? effectiveEnd
            : b.endTime;

        if (effEnd.isBefore(effStart) || effStart == effEnd) continue;

        // Gap before block = phone rest
        if (effStart.isAfter(cursor)) {
          final gapSec = effStart.difference(cursor).inSeconds;
          if (gapSec >= 3) {
            chronologicalEvents.add(
              RestTimelineEvent(
                startTime: cursor,
                endTime: effStart,
                durationSeconds: gapSec,
              ),
            );
          }
        }

        final dur = effEnd.difference(effStart).inSeconds;
        if (b.isActiveScreen) {
          usedSec += dur;

          // Extract app switch steps within this active session
          final appSteps = _extractAppIntervals(
            sessionStart: effStart,
            sessionEnd: effEnd,
            block: b,
          );
          chronologicalEvents.addAll(appSteps);
        } else {
          chronologicalEvents.add(
            RestTimelineEvent(
              startTime: effStart,
              endTime: effEnd,
              durationSeconds: dur,
            ),
          );
        }

        cursor = effEnd;
      }

      // Remaining gap at the end of the observed period = rest
      if (effectiveEnd.isAfter(cursor)) {
        final remSec = effectiveEnd.difference(cursor).inSeconds;
        if (remSec >= 3) {
          chronologicalEvents.add(
            RestTimelineEvent(
              startTime: cursor,
              endTime: effectiveEnd,
              durationSeconds: remSec,
            ),
          );
        }
      }

      // Process real alert milestones logged for this hour (Option B: embed inside active app if ongoing)
      bool hasRealAlert = false;
      for (final ts in widget.alertTimestamps) {
        if (!ts.isBefore(winStart) && !ts.isAfter(effectiveEnd)) {
          hasRealAlert = true;

          // 1. Check if this alert occurred during an ongoing app session
          int embeddedIndex = -1;
          for (int i = 0; i < chronologicalEvents.length; i++) {
            final ev = chronologicalEvents[i];
            if (ev is AppUsageTimelineEvent) {
              if (!ts.isBefore(ev.startTime) && !ts.isAfter(ev.endTime)) {
                embeddedIndex = i;
                break;
              }
            }
          }

          if (embeddedIndex != -1) {
            final appEv =
                chronologicalEvents[embeddedIndex] as AppUsageTimelineEvent;
            chronologicalEvents[embeddedIndex] = appEv.copyWith(
              alertTriggerTime: ts,
            );
          } else {
            // 2. Check if this alert immediately prompted an app session right after (within 15s)
            int promptedIndex = -1;
            for (int i = 0; i < chronologicalEvents.length; i++) {
              final ev = chronologicalEvents[i];
              if (ev is AppUsageTimelineEvent) {
                final diffSec = ev.startTime.difference(ts).inSeconds;
                if (diffSec >= 0 && diffSec <= 15) {
                  promptedIndex = i;
                  break;
                }
              }
            }

            if (promptedIndex != -1) {
              final appEv =
                  chronologicalEvents[promptedIndex] as AppUsageTimelineEvent;
              // Clamp any preceding rest block that overlapped ts to ts
              for (int j = 0; j < chronologicalEvents.length; j++) {
                final rev = chronologicalEvents[j];
                if (rev is RestTimelineEvent &&
                    rev.endTime.isAfter(ts) &&
                    !rev.startTime.isAfter(ts)) {
                  final newDur = ts.difference(rev.startTime).inSeconds;
                  if (newDur > 0) {
                    chronologicalEvents[j] = rev.copyWith(
                      endTime: ts,
                      durationSeconds: newDur,
                    );
                  }
                }
              }

              chronologicalEvents[promptedIndex] = appEv.copyWith(
                alertTriggerTime: ts,
              );
            } else {
              // 3. Standalone alert (or occurred during rest)
              for (int j = 0; j < chronologicalEvents.length; j++) {
                final rev = chronologicalEvents[j];
                if (rev is RestTimelineEvent &&
                    !ts.isBefore(rev.startTime) &&
                    !ts.isAfter(rev.endTime)) {
                  final newDur = ts.difference(rev.startTime).inSeconds;
                  if (newDur > 0) {
                    chronologicalEvents[j] = rev.copyWith(
                      endTime: ts,
                      durationSeconds: newDur,
                    );
                  }
                }
              }

              final isAlreadyPresent = chronologicalEvents.any(
                (e) =>
                    e is AlertTimelineEvent &&
                    (e.alertTime.difference(ts).inMinutes.abs() < 2),
              );
              if (!isAlreadyPresent) {
                chronologicalEvents.add(
                  AlertTimelineEvent(alertTime: ts, text: 'Eye Break Alert'),
                );
              }
            }
          }
        }
      }

      // Sort all events strictly by chronological timestamp
      chronologicalEvents.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Calculate exact second-level stop actions and rest responses
      for (int i = 0; i < chronologicalEvents.length; i++) {
        final ev = chronologicalEvents[i];
        if (ev is AppUsageTimelineEvent) {
          final nextEv = (i + 1 < chronologicalEvents.length)
              ? chronologicalEvents[i + 1]
              : null;

          String stopReason = '';
          int? nextRestSec;

          if (nextEv is RestTimelineEvent) {
            nextRestSec = nextEv.durationSeconds;
            final restFormatted =
                HourlyWaterChipsStoryboard.formatDurationWithSeconds(nextRestSec);
            if (ev.alertTriggerTime != null) {
              final delaySec = max(
                0,
                ev.endTime.difference(ev.alertTriggerTime!).inSeconds,
              );
              if (delaySec <= 15) {
                stopReason =
                    'Screen locked in ${delaySec}s • Rested for $restFormatted ✓';
              } else {
                stopReason = 'Rested for $restFormatted ✓';
              }
            }
          } else if (nextEv is AppUsageTimelineEvent) {
            // Next is another app: timestamps and seconds speak for themselves without clutter
            stopReason = '';
          } else {
            // Last event in hour
            if (isCurrentHour && now.difference(ev.endTime).inSeconds < 60) {
              stopReason = 'Active now';
            }
          }

          chronologicalEvents[i] = ev.copyWith(
            stopAction: stopReason,
            restAfterSeconds: nextRestSec,
          );
        } else if (ev is AlertTimelineEvent) {
          final nextEv = (i + 1 < chronologicalEvents.length)
              ? chronologicalEvents[i + 1]
              : null;
          String stopExpl = '';
          if (nextEv is RestTimelineEvent) {
            final delaySec = max(
              0,
              nextEv.startTime.difference(ev.alertTime).inSeconds,
            );
            final restFormatted =
                HourlyWaterChipsStoryboard.formatDurationWithSeconds(
                  nextEv.durationSeconds,
                );
            if (delaySec <= 15) {
              stopExpl =
                  'Screen locked in ${delaySec}s • Rested $restFormatted ✓';
            } else {
              stopExpl = 'Rested for $restFormatted ✓';
            }
          }
          if (stopExpl.isNotEmpty) {
            chronologicalEvents[i] = ev.copyWith(stopExplanation: stopExpl);
          }
        }
      }

      // Compute Apps Summary Chips for this hour
      final appMap = <String, AppSummaryChip>{};
      for (final ev in chronologicalEvents.whereType<AppUsageTimelineEvent>()) {
        final lower = ev.name.toLowerCase().trim();
        // NEVER include internal placeholders like "Screen Active" or "Home Screen" in the apps summary chips
        if (lower == 'screen active' ||
            lower == 'home screen' ||
            lower == 'home' ||
            lower.isEmpty) {
          continue;
        }

        if (appMap.containsKey(ev.name)) {
          final existing = appMap[ev.name]!;
          appMap[ev.name] = AppSummaryChip(
            name: ev.name,
            package: ev.package.isNotEmpty ? ev.package : existing.package,
            totalSeconds: existing.totalSeconds + ev.durationSeconds,
          );
        } else {
          appMap[ev.name] = AppSummaryChip(
            name: ev.name,
            package: ev.package,
            totalSeconds: ev.durationSeconds,
          );
        }
      }
      final appsSummary = appMap.values.toList()
        ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

      usedSec = usedSec.clamp(0, elapsedSeconds);
      final restSec = (elapsedSeconds - usedSec).clamp(0, 3600);

      // If no blocks at all for this hour and time has elapsed, 100% rest
      if (chronologicalEvents.where((e) => e is! AlertTimelineEvent).isEmpty && elapsedSeconds > 0) {
        chronologicalEvents.add(
          RestTimelineEvent(
            startTime: winStart,
            endTime: effectiveEnd,
            durationSeconds: elapsedSeconds,
          ),
        );
      }

      result.add(
        HourSliceData(
          hour: h,
          label: HourSliceData._shortLabel(h),
          windowStart: winStart,
          windowEnd: winEnd,
          usedSeconds: usedSec,
          restSeconds: restSec,
          elapsedSeconds: elapsedSeconds,
          isCurrentHour: isCurrentHour,
          hasAlert: hasRealAlert,
          apps: appsSummary,
          events: chronologicalEvents,
        ),
      );
    }

    _hours = result;
  }

  void _selectHour(int h) {
    if (h >= 0 && h < 24) {
      if (h != _selectedHour) {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedHour = h;
        });
      }
      widget.onHourSelected?.call(h);
    }
  }

  void _stepHour(int direction) {
    final next = (_selectedHour + direction + 24) % 24;
    _selectHour(next);
  }

  Widget _buildArrowStepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 34,
          decoration: BoxDecoration(
            color: widget.blueColor.withValues(
              alpha: widget.isDark ? 0.16 : 0.10,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.blueColor.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: widget.blueColor),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHourData = _hours[_selectedHour];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Controls Row: Legend + Prev/Next Buttons according to pointer
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Legend
            Row(
              children: [
                _buildLegendItem(color: widget.blueColor, label: 'Used'),
                const SizedBox(width: 8),
                _buildLegendItem(color: widget.mintColor, label: 'Rested'),
                const SizedBox(width: 8),
                _buildLegendItem(color: widget.amberColor, label: 'Alert'),
              ],
            ),

            // Step Buttons with current pointer hour
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildArrowStepButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous hour',
                  onTap: () => _stepHour(-1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: (widget.isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (widget.isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      HourSliceData._formatHourWithAmPm(_selectedHour),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: widget.isDark ? Colors.white : widget.blueColor,
                      ),
                    ),
                  ),
                ),
                _buildArrowStepButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next hour',
                  onTap: () => _stepHour(1),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. THE 24 HOURLY CAPSULE CHIPS (3 ROWS OF 8 COLUMNS - DIRECTLY ON SURFACE, ZERO OUTER BOX)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Night & Early Morning (Hours 0 - 7)
            _buildHourRow(
              title: 'Night & Morning',
              timeRange: '12 AM – 8 AM',
              startHour: 0,
              endHour: 7,
            ),

            const SizedBox(height: 10),

            // Row 2: Daytime & Afternoon (Hours 8 - 15)
            _buildHourRow(
              title: 'Daytime & Afternoon',
              timeRange: '8 AM – 4 PM',
              startHour: 8,
              endHour: 15,
            ),

            const SizedBox(height: 10),

            // Row 3: Evening & Night (Hours 16 - 23)
            _buildHourRow(
              title: 'Evening & Night',
              timeRange: '4 PM – 12 AM',
              startHour: 16,
              endHour: 23,
            ),
          ],
        ),

        const SizedBox(height: 22),
        Divider(height: 1, thickness: 0.6, color: widget.dividerColor),
        const SizedBox(height: 20),

        // 3. THE CUTE CHIPS DETAIL CARD FOR THE SELECTED HOUR
        _buildCuteHourDetailCard(currentHourData),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: widget.isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHourRow({
    required String title,
    required String timeRange,
    required int startHour,
    required int endHour,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: widget.isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(8, (idx) {
            final h = startHour + idx;
            final data = _hours[h];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: idx == 0 ? 0 : 2.5,
                  right: idx == 7 ? 0 : 2.5,
                ),
                child: _buildWaterChip(data),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildWaterChip(HourSliceData data) {
    final isSelected = data.hour == _selectedHour;
    final isFuture = data.isFuture;
    final isFilterActive =
        widget.selectedAppPackage != null &&
        widget.selectedAppPackage!.isNotEmpty;
    final hasSelectedApp = _hourMatchesSelectedApp(data);
    final chipOpacity = isFilterActive ? (hasSelectedApp ? 1.0 : 0.22) : 1.0;

    return GestureDetector(
      onTap: () => _selectHour(data.hour),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: chipOpacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (widget.isDark
                      ? widget.blueColor.withValues(alpha: 0.25)
                      : widget.blueColor.withValues(alpha: 0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? (widget.isDark ? Colors.white : widget.blueColor)
                  : (data.isCurrentHour
                        ? widget.blueColor.withValues(alpha: 0.5)
                        : (isFilterActive && hasSelectedApp
                              ? widget.blueColor.withValues(alpha: 0.5)
                              : Colors.transparent)),
              width: isSelected
                  ? 1.5
                  : (isFilterActive && hasSelectedApp ? 1.2 : 1),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: widget.blueColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : (isFilterActive && hasSelectedApp
                      ? [
                          BoxShadow(
                            color: widget.blueColor.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ]
                      : null),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Capsule filled in real chronological order
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isFuture
                          ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : AppColors.lightCapsuleFuture)
                          : (widget.isDark
                                ? AppColors.darkCapsuleGlass
                                : AppColors.lightCapsuleGlass),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: data.isCurrentHour
                            ? (widget.isDark
                                  ? widget.blueColor.withValues(alpha: 0.40)
                                  : widget.blueColor.withValues(alpha: 0.70))
                            : (widget.isDark
                                  ? Colors.white.withValues(alpha: isFuture ? 0.04 : 0.10)
                                  : (isFuture
                                        ? AppColors.lightCapsuleFutureBorder
                                        : AppColors.lightCapsuleBorder)),
                        width: widget.isDark ? 0.8 : 1.0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isFuture
                        ? null
                        : Column(
                            children: [
                              // Handle 100% complete rest hour explicitly
                              if (data.usedSeconds == 0 && data.elapsedSeconds > 0) ...[
                                Flexible(
                                  flex: max(1, (data.elapsedSeconds * 100) ~/ 3600),
                                  child: Container(
                                    width: double.infinity,
                                    color: isSelected
                                        ? widget.mintColor
                                        : (widget.isDark
                                              ? widget.mintColor.withValues(alpha: 0.60)
                                              : widget.mintColor),
                                  ),
                                ),
                                if (data.isCurrentHour && data.remainingMinutes > 0)
                                  Flexible(
                                    flex: max(
                                      1,
                                      (data.remainingMinutes * 60 * 100) ~/ 3600,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      color: (widget.isDark
                                              ? Colors.white
                                              : Colors.black)
                                          .withValues(alpha: 0.04),
                                    ),
                                  ),
                              ] else ...[
                                ...data.events.map((ev) {
                                  if (ev is AlertTimelineEvent) {
                                    return const SizedBox.shrink();
                                  }

                                  if (isFilterActive) {
                                    // Hide rest & hide other apps when an app is selected
                                    if (ev is! AppUsageTimelineEvent ||
                                        !_isTargetApp(ev.package, ev.name)) {
                                      return const SizedBox.shrink();
                                    }

                                    final durSec = ev.durationSeconds;
                                    final flex = max(1, (durSec * 100) ~/ 3600);
                                    return Flexible(
                                      flex: flex,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: widget.blueColor,
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.black.withValues(
                                                alpha: 0.15,
                                              ),
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final isApp = ev is AppUsageTimelineEvent;
                                  final durSec = isApp
                                      ? ev.durationSeconds
                                      : (ev as RestTimelineEvent).durationSeconds;

                                  final flex = max(1, (durSec * 100) ~/ 3600);
                                  final color = isApp
                                      ? (isSelected
                                            ? widget.blueColor
                                            : (widget.isDark
                                                  ? widget.blueColor.withValues(alpha: 0.80)
                                                  : widget.blueColor))
                                      : (isSelected
                                            ? widget.mintColor
                                            : (widget.isDark
                                                  ? widget.mintColor.withValues(alpha: 0.60)
                                                  : widget.mintColor));

                                  return Flexible(
                                    flex: flex,
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: color,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                // Unelapsed portion for current hour remains clean/empty
                                if (data.isCurrentHour &&
                                    data.remainingMinutes > 0)
                                  Flexible(
                                    flex: max(
                                      1,
                                      (data.remainingMinutes * 60 * 100) ~/ 3600,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      color:
                                          (widget.isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withValues(alpha: 0.04),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                  ),

                  // Center minutes label (shows specific app minutes when filtered)
                  if (!isFuture &&
                      (isFilterActive
                          ? _getSelectedAppMinutesInHour(data) > 0
                          : data.usedMinutes > 0))
                    Positioned.fill(
                      child: Center(
                        child: Text(
                          '${isFilterActive ? _getSelectedAppMinutesInHour(data) : data.usedMinutes}m',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Selected App Dot on Top-Left (when filtering by selected app)
                  if (!isFuture && isFilterActive && hasSelectedApp)
                    Positioned(
                      top: -3,
                      left: -3,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: widget.blueColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? AppColors.darkCapsuleBoard
                                : Colors.white,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.blueColor.withValues(alpha: 0.9),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Alert Dot on Top-Right (glowing amber/yellow badge when alert occurred)
                  if (!isFuture && data.hasAlert)
                    Positioned(
                      top: -2.5,
                      right: -2.5,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.marathonAmberLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? AppColors.darkCapsuleBoard
                                : Colors.white,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.marathonAmberLight.withValues(
                                alpha: 0.85,
                              ),
                              blurRadius: 5,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 3),

              // Hour Label (12 AM, 1 AM, 2 AM...)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 8.8,
                    fontWeight: isSelected
                        ? FontWeight.w800
                        : (data.isCurrentHour
                              ? FontWeight.w700
                              : FontWeight.w600),
                    color: isSelected
                        ? (widget.isDark ? Colors.white : AppColors.textPrimary)
                        : (data.isCurrentHour
                              ? widget.blueColor
                              : (isFuture
                                    ? (widget.isDark
                                          ? Colors.white24
                                          : Colors.black26)
                                    : (widget.isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Minimal Cute Chips Detail View (Cardless / Surface Layout)
  Widget _buildCuteHourDetailCard(HourSliceData data) {
    if (data.isFuture) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 24,
              color: widget.isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.textTertiary,
            ),
            const SizedBox(height: 6),
            Text(
              '${data.displayTimeRange} is upcoming',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Screen time and rest will be tracked as this hour unfolds.',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    final isFilterActive =
        widget.selectedAppPackage != null &&
        widget.selectedAppPackage!.isNotEmpty;
    final hasUsage = isFilterActive
        ? _getSelectedAppSecondsInHour(data) > 0
        : data.usedMinutes > 0;
    final primaryColor = hasUsage ? widget.blueColor : widget.mintColor;

    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Hour Range on top, Active & Rest time brought DOWN below (Zero Congestion)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Hour Range (e.g. "10:00 AM → 11:00 AM" with optional "Now" badge)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.displayTimeRange,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? Colors.white
                          : AppColors.textCharcoal,
                    ),
                  ),
                  if (data.isCurrentHour) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.amberColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: widget.amberColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),

              // Row 2: Active and Rest time brought DOWN (peaceful, un-congested, ample room!)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Active / Used
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.blueColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isFilterActive
                            ? _getSelectedAppFormattedDuration(data)
                            : HourlyWaterChipsStoryboard.formatDurationWithSeconds(data.usedSeconds),
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: widget.blueColor,
                        ),
                      ),
                      Text(
                        ' used',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: widget.isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  if (!isFilterActive) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '•',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ),

                    // Rest
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.mintColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          HourlyWaterChipsStoryboard.formatDurationWithSeconds(data.restSeconds),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: widget.mintColor,
                          ),
                        ),
                        Text(
                          ' rest',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(height: 1, thickness: 0.6, color: widget.dividerColor),
          const SizedBox(height: 18),

          // 2. APPS USED IN THIS HOUR (SHOW ONLY SELECTED APP WHEN FILTERED)
          Row(
            children: [
              Text(
                isFilterActive
                    ? 'Selected App in this Hour:'
                    : 'Apps Used in this Hour:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              if (!isFilterActive) ...[
                const SizedBox(width: 4),
                Text(
                  '(${data.apps.length} app${data.apps.length > 1 ? "s" : ""})',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),

          Builder(
            builder: (context) {
              final matchingApps = isFilterActive
                  ? data.apps
                        .where((app) => _isTargetApp(app.package, app.name))
                        .toList()
                  : data.apps;

              if (matchingApps.isNotEmpty) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: matchingApps.map((app) {
                      final isTarget = _isTargetApp(app.package, app.name);

                      return GestureDetector(
                        onTap: widget.onAppSelected != null
                            ? () {
                                HapticFeedback.selectionClick();
                                widget.onAppSelected!(
                                  isTarget
                                      ? null
                                      : (app.package.isNotEmpty
                                            ? app.package
                                            : app.name),
                                );
                              }
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          margin: const EdgeInsets.only(right: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isTarget
                                ? widget.blueColor.withValues(
                                    alpha: widget.isDark ? 0.20 : 0.10,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isTarget
                                  ? widget.blueColor
                                  : Colors.transparent,
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1. App Icon
                              AppIconBadge(
                                packageName: app.package,
                                appName: app.name,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              // 2. Duration (e.g. "26m", "12m 30s") directly below icon
                              Text(
                                app.formattedDuration,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: isTarget
                                      ? widget.blueColor
                                      : (widget.isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.textSlateNavy),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }

              if (isFilterActive) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Not used in this hour',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: widget.mintColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.mintColor.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_outlined, size: 14, color: widget.mintColor),
                    const SizedBox(width: 6),
                    Text(
                      'No screen usage • 100% Phone Rest',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.mintColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 22),
          Divider(height: 1, thickness: 0.6, color: widget.dividerColor),
          const SizedBox(height: 20),

          // 3. CHRONOLOGICAL TIMELINE (MINIMAL CUTE CHIPS FLOW)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Minute-by-Minute Timeline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showMinuteDetails = !_showMinuteDetails;
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _showMinuteDetails
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: widget.blueColor,
                ),
                label: Text(
                  _showMinuteDetails ? 'Hide details' : 'Show in detail',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.blueColor,
                  ),
                ),
              ),
            ],
          ),

          if (_showMinuteDetails) ...[
            const SizedBox(height: 14),

            // 1. Sleek 60-minute segmented mini-rail track
            _buildHourMiniStrip(data, isFilterActive),

            const SizedBox(height: 20),

            // 2. Connected Chronological Timeline (Option 1)
            Builder(
              builder: (context) {
                final eventsToShow = isFilterActive
                    ? data.events
                          .whereType<AppUsageTimelineEvent>()
                          .where((ev) => _isTargetApp(ev.package, ev.name))
                          .toList()
                    : data.events;

                if (eventsToShow.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        isFilterActive
                            ? 'No sessions for this app in this hour'
                            : 'No events in this hour',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < eventsToShow.length; i++) ...[
                      Builder(
                        builder: (context) {
                          final event = eventsToShow[i];
                          final isFirst = i == 0;
                          final isLast = i == eventsToShow.length - 1;

                          if (event is AlertTimelineEvent) {
                            return _buildTimelineItem(
                              isFirst: isFirst,
                              isLast: isLast,
                              node: _buildAlertTimelineNode(),
                              content: _buildCuteAlertContent(event),
                            );
                          } else if (event is RestTimelineEvent) {
                            return _buildTimelineItem(
                              isFirst: isFirst,
                              isLast: isLast,
                              node: _buildRestTimelineNode(),
                              content: _buildCuteRestContent(event),
                            );
                          } else if (event is AppUsageTimelineEvent) {
                            return _buildTimelineItem(
                              isFirst: isFirst,
                              isLast: isLast,
                              node: _buildAppIconTimelineNode(event),
                              content: _buildCuteAppContent(event),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 60-minute segmented mini-rail track across the hour
  Widget _buildHourMiniStrip(HourSliceData data, bool isFilterActive) {
    // Collect genuine alerts that fall within this hour
    final alertsInHour = widget.alertTimestamps.where((ts) {
      return !ts.isBefore(data.windowStart) && !ts.isAfter(data.windowEnd);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final segmentWidgets = <Widget>[];

            for (final ev in data.events) {
              if (ev is AppUsageTimelineEvent) {
                final isTarget =
                    isFilterActive && _isTargetApp(ev.package, ev.name);
                final segColor = isFilterActive
                    ? (isTarget
                          ? widget.blueColor
                          : widget.blueColor.withValues(alpha: 0.25))
                    : widget.blueColor;

                segmentWidgets.add(
                  Expanded(
                    flex: max(1, ev.durationSeconds),
                    child: Container(color: segColor),
                  ),
                );
              } else if (ev is RestTimelineEvent) {
                final segColor = isFilterActive
                    ? widget.mintColor.withValues(alpha: 0.3)
                    : widget.mintColor;

                segmentWidgets.add(
                  Expanded(
                    flex: max(1, ev.durationSeconds),
                    child: Container(color: segColor),
                  ),
                );
              }
            }

            // Current hour unelapsed remaining time
            if (data.isCurrentHour && data.remainingMinutes > 0) {
              final remainingSec = (3600 - data.elapsedSeconds).clamp(0, 3600);
              if (remainingSec > 0) {
                segmentWidgets.add(
                  Expanded(
                    flex: remainingSec,
                    child: Container(
                      color: (widget.isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.07),
                    ),
                  ),
                );
              }
            } else if (segmentWidgets.isEmpty) {
              // Entire hour rested / empty
              segmentWidgets.add(
                Expanded(flex: 3600, child: Container(color: widget.mintColor)),
              );
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: segmentWidgets,
                    ),
                  ),
                ),

                // Amber Alert Pins positioned along the rail
                ...alertsInHour.map((alertTime) {
                  final sec = alertTime
                      .difference(data.windowStart)
                      .inSeconds
                      .clamp(0, 3600);
                  final pct = sec / 3600.0;
                  final pinX = (totalWidth * pct).clamp(
                    0.0,
                    max(0.0, totalWidth - 8.0),
                  );

                  return Positioned(
                    left: double.parse(pinX.toString()),
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.amberColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isDark
                              ? AppColors.darkCardSurface
                              : Colors.white,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.amberColor.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),

        const SizedBox(height: 5),

        // 60-min interval labels: :00, :15, :30, :45, :60
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTickText(':00'),
            _buildTickText(':15'),
            _buildTickText(':30'),
            _buildTickText(':45'),
            _buildTickText(':60'),
          ],
        ),
      ],
    );
  }

  Widget _buildTickText(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        color: widget.isDark
            ? AppColors.darkTextTertiary
            : AppColors.textTertiary,
      ),
    );
  }

  /// Option 1 Connected Timeline Item (using IntrinsicHeight for unbroken vertical line)
  Widget _buildTimelineItem({
    required bool isFirst,
    required bool isLast,
    required Widget node,
    required Widget content,
  }) {
    final lineColor = (widget.isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.12,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left timeline column: line + node + line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Top line connector
                SizedBox(
                  height: 2,
                  child: isFirst
                      ? null
                      : Center(child: Container(width: 1.5, color: lineColor)),
                ),
                // Node
                node,
                // Bottom line connector
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(child: Container(width: 1.5, color: lineColor)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: isLast ? 4 : 22),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIconTimelineNode(AppUsageTimelineEvent ev) {
    final hasAlert = ev.alertTriggerTime != null;
    final lowerName = ev.name.toLowerCase();
    final lowerPkg = ev.package.toLowerCase();
    final isHome = lowerName.contains('home') ||
        lowerPkg.contains('launcher') ||
        lowerPkg.contains('systemui') ||
        lowerName == 'screen active';

    if (isHome) {
      // Home screen keeps the round circular container as requested
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkCardSurface : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isDark ? Colors.white24 : Colors.black12,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.home_rounded,
          size: 15,
          color: widget.isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
      );
    }

    // Regular App: NO round outer container! App icon rendered directly & bigger (size 26)
    if (hasAlert) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AppIconBadge(
            packageName: ev.package,
            appName: ev.name,
            size: 26,
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.amberColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isDark
                      ? AppColors.darkCardSurface
                      : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.amberColor.withValues(alpha: 0.5),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AppIconBadge(
      packageName: ev.package,
      appName: ev.name,
      size: 26,
    );
  }

  Widget _buildRestTimelineNode() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: widget.mintColor.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.mintColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.spa_outlined,
        size: 15,
        color: widget.mintColor,
      ),
    );
  }

  Widget _buildAlertTimelineNode() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: widget.amberColor.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.amberColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.notifications_active_rounded,
        size: 15,
        color: widget.amberColor,
      ),
    );
  }

  /// Cute App Content with Exact Second Timestamps & Stop Actions
  Widget _buildCuteAppContent(AppUsageTimelineEvent ev) {
    final hasAlert = ev.alertTriggerTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Exact start and end time with seconds
            Text(
              '${HourlyWaterChipsStoryboard.formatTimeWithSeconds(ev.startTime)} → ${HourlyWaterChipsStoryboard.formatTimeWithSeconds(ev.endTime)}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textSlateNavy,
              ),
            ),

            // Duration pill with seconds (e.g. 15m 22s or 45s)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: hasAlert
                    ? widget.amberColor.withValues(alpha: 0.16)
                    : widget.blueColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ev.formattedDuration,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: hasAlert ? widget.amberColor : widget.blueColor,
                ),
              ),
            ),
          ],
        ),

        // Embedded Alert Tag showing exact second alert triggered and how they stopped
        if (hasAlert) ...[
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.amberColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: widget.amberColor.withValues(alpha: 0.28),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 12,
                      color: widget.amberColor,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Alert triggered at ${HourlyWaterChipsStoryboard.formatTimeWithSeconds(ev.alertTriggerTime!)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: widget.amberColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (ev.stopAction != null && ev.stopAction!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 11,
                        color: widget.mintColor,
                      ),
                      const SizedBox(width: 4.5),
                      Expanded(
                        child: Text(
                          ev.stopAction!,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: widget.mintColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ] else if (ev.stopAction != null && ev.stopAction!.isNotEmpty) ...[
          const SizedBox(height: 3.5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.mintColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    ev.stopAction!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: widget.mintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Cute Rest Content with Exact Second Timestamps
  Widget _buildCuteRestContent(RestTimelineEvent ev) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Exact start and end time with seconds
        Text(
          '${HourlyWaterChipsStoryboard.formatTimeWithSeconds(ev.startTime)} → ${HourlyWaterChipsStoryboard.formatTimeWithSeconds(ev.endTime)}',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: widget.mintColor,
          ),
        ),

        // Duration pill with seconds (e.g. 2m 14s)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: widget.mintColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            ev.formattedDuration,
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: widget.mintColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Cute Standalone Alert Content with Exact Seconds and Stop Explanation
  Widget _buildCuteAlertContent(AlertTimelineEvent ev) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              HourlyWaterChipsStoryboard.formatTimeWithSeconds(ev.alertTime),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: widget.amberColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: widget.amberColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Alert',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.amberColor,
                ),
              ),
            ),
          ],
        ),
        if (ev.stopExplanation != null && ev.stopExplanation!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 11,
                  color: widget.mintColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ev.stopExplanation!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: widget.mintColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:$m $period';
  }
}
