import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../features/eye_rest/domain/entities/screen_activity_block.dart';

/// SystemScreenTimeService
///
/// Direct bridge to Android's native UsageStatsManager and AlarmManager:
/// 1. UsageStatsManager: Reads system-level screen ON (Active Screen) and screen OFF (Phone Rest)
///    intervals recorded 24/7 by the Android OS kernel, even when the app is in killed state.
/// 2. AlarmManager: Sets exact 20-minute gentle gaze reminders that wake from killed state
///    without needing any persistent status bar notification badge.
class SystemScreenTimeService {
  static const MethodChannel _channel = MethodChannel('com.reset/call_proximity');

  /// Checks if the user has granted Android Usage Access permission.
  static Future<bool> hasUsagePermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasUsageStatsPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android Settings -> Usage Access page for LifeMint.
  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (_) {}
  }

  /// Schedules the native 20-minute exact alarm that fires in killed state.
  static Future<void> scheduleExactReminder({int seconds = 1200}) async {
    try {
      await _channel.invokeMethod('scheduleExactEyeReminder', {'seconds': seconds});
    } catch (_) {}
  }

  /// Cancels the native exact alarm.
  static Future<void> cancelExactReminder() async {
    try {
      await _channel.invokeMethod('cancelExactEyeReminder');
    } catch (_) {}
  }

  /// Queries Android hardware system clocks (uptimeMillis & elapsedRealtime)
  /// to measure true active wake time vs deep sleep when app was killed.
  static Future<Map<String, int>?> getSystemClocks() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getSystemClocks');
      if (res != null) {
        return {
          'uptimeMs': (res['uptimeMs'] as num).toInt(),
          'elapsedRealtimeMs': (res['elapsedRealtimeMs'] as num).toInt(),
        };
      }
    } catch (_) {}
    return null;
  }

  static final Map<String, Uint8List?> _iconCache = {};

  /// Retrieves the PNG icon bytes for an installed application package.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    if (packageName.isEmpty) return null;
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      _iconCache[packageName] = bytes;
      return bytes;
    } catch (_) {
      _iconCache[packageName] = null;
      return null;
    }
  }

  /// Returns the exact timestamp (epoch milliseconds) of when the app was installed on the device.
  static Future<int> getAppInstallTime() async {
    try {
      final res = await _channel.invokeMethod<dynamic>('getAppInstallTime');
      if (res is num) return res.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Queries real system-level Screen ON and Phone Rest blocks for a given date.
  /// If [date] is omitted, defaults to today.
  /// [requiredRestSeconds] passes the user's custom rest duration (e.g. 20s, 40s, 120s)
  /// so continuous active strain calculations properly bridge intervals < requiredRestSeconds.
  static Future<SystemUsageResult> getScreenAndRestBlocks({
    DateTime? date,
    int? requiredRestSeconds,
  }) async {
    final target = date ?? DateTime.now();
    final startOfDay = DateTime(target.year, target.month, target.day);
    final endOfDay = target.day == DateTime.now().day &&
            target.month == DateTime.now().month &&
            target.year == DateTime.now().year
        ? DateTime.now()
        : DateTime(target.year, target.month, target.day, 23, 59, 59, 999);

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceScreenAndRestBlocks',
        {
          'startTimeMs': startOfDay.millisecondsSinceEpoch,
          'endTimeMs': endOfDay.millisecondsSinceEpoch,
          'requiredRestSeconds': requiredRestSeconds ?? 120,
        },
      );

      if (res == null) {
        return SystemUsageResult.empty();
      }

      final activeSeconds = (res['activeScreenSeconds'] as num?)?.toInt() ?? 0;
      final restSeconds = (res['phoneRestSeconds'] as num?)?.toInt() ?? 0;
      final continuousSec = (res['currentContinuousActiveSeconds'] as num?)?.toInt() ?? 0;
      final rawBlocks = (res['blocks'] as List<dynamic>?) ?? [];

      final blocks = <ScreenActivityBlock>[];
      for (final raw in rawBlocks) {
        if (raw is Map) {
          final startStr = raw['startTime'] as String?;
          final endStr = raw['endTime'] as String?;
          final typeStr = raw['type'] as String?;

          if (startStr != null && endStr != null) {
            final start = (DateTime.tryParse(startStr) ?? startOfDay).toLocal();
            final end = (DateTime.tryParse(endStr) ?? endOfDay).toLocal();
            final type = typeStr == 'phoneRest'
                ? ActivityType.phoneRest
                : ActivityType.activeScreen;

            final rawApps = (raw['topApps'] as List<dynamic>?) ?? [];
            final topApps = rawApps.map((a) {
              if (a is Map) {
                return AppUsageSnippet(
                  name: a['name'] as String? ?? 'App',
                  package: a['package'] as String? ?? '',
                  seconds: (a['seconds'] as num?)?.toInt() ?? 0,
                );
              }
              return const AppUsageSnippet(name: 'App', package: '', seconds: 0);
            }).toList();

            final hasBgAudio = (raw['hasBackgroundAudio'] as bool?) ?? false;
            final audioApp = raw['audioAppName'] as String? ?? '';
            final isOverrun = (raw['isOverrun'] as bool?) ?? false;

            blocks.add(ScreenActivityBlock(
              startTime: start,
              endTime: end,
              type: type,
              topApps: topApps,
              hasBackgroundAudio: hasBgAudio,
              audioAppName: audioApp,
              isOverrun: isOverrun,
            ));
          }
        }
      }

      final rawAppSummary = (res['appSummary'] as List<dynamic>?) ?? [];
      final appUsages = <AppCumulativeUsage>[];
      for (final item in rawAppSummary) {
        if (item is Map) {
          final name = item['name'] as String? ?? 'App';
          final pkg = item['package'] as String? ?? '';
          final totalSec = (item['totalSeconds'] as num?)?.toInt() ?? 0;
          final rawIntervals = (item['intervals'] as List<dynamic>?) ?? [];
          final intervals = <AppSessionInterval>[];
          for (final intr in rawIntervals) {
            if (intr is Map) {
              final sStr = intr['startTime'] as String?;
              final eStr = intr['endTime'] as String?;
              final dur = (intr['durationSeconds'] as num?)?.toInt() ?? 0;
              if (sStr != null && eStr != null && dur >= 3) {
                intervals.add(AppSessionInterval(
                  startTime: (DateTime.tryParse(sStr) ?? startOfDay).toLocal(),
                  endTime: (DateTime.tryParse(eStr) ?? endOfDay).toLocal(),
                  durationSeconds: dur,
                ));
              }
            }
          }
          appUsages.add(AppCumulativeUsage(
            name: name,
            package: pkg,
            totalSeconds: totalSec,
            intervals: intervals,
          ));
        }
      }

      return SystemUsageResult(
        activeScreenSeconds: activeSeconds,
        phoneRestSeconds: restSeconds,
        currentContinuousActiveSeconds: continuousSec,
        blocks: blocks,
        appUsages: appUsages,
        hasPermission: true,
      );
    } catch (_) {
      return SystemUsageResult.empty();
    }
  }
}

/// AppSessionInterval
class AppSessionInterval {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;

  const AppSessionInterval({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
  });

  Duration get duration => Duration(seconds: durationSeconds);
}

/// AppCumulativeUsage
class AppCumulativeUsage {
  final String name;
  final String package;
  final int totalSeconds;
  final List<AppSessionInterval> intervals;

  const AppCumulativeUsage({
    required this.name,
    required this.package,
    required this.totalSeconds,
    this.intervals = const [],
  });

  Duration get duration => Duration(seconds: totalSeconds);
  int get sessionCount => intervals.length;

  String get formattedDuration {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final m = (totalSeconds + 30) ~/ 60;
    if (m < 60) {
      return '$m min';
    }
    final h = m ~/ 60;
    final remM = m % 60;
    if (remM == 0) return '${h}h';
    return '${h}h ${remM}m';
  }
}

/// SystemUsageResult
class SystemUsageResult {
  final int activeScreenSeconds;
  final int phoneRestSeconds;
  final int currentContinuousActiveSeconds;
  final List<ScreenActivityBlock> blocks;
  final List<AppCumulativeUsage> appUsages;
  final bool hasPermission;

  const SystemUsageResult({
    required this.activeScreenSeconds,
    required this.phoneRestSeconds,
    required this.currentContinuousActiveSeconds,
    required this.blocks,
    this.appUsages = const [],
    required this.hasPermission,
  });

  factory SystemUsageResult.empty() => const SystemUsageResult(
        activeScreenSeconds: 0,
        phoneRestSeconds: 0,
        currentContinuousActiveSeconds: 0,
        blocks: [],
        appUsages: const [],
        hasPermission: false,
      );
}

