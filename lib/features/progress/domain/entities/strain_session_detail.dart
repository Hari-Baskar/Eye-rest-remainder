import '../../../eye_rest/domain/entities/screen_activity_block.dart';

/// StrainSessionDetail
///
/// Immutable domain model capturing a user's uninterrupted continuous screen session.
/// Automatically bridges micro-pauses (< 30s) so accidental phone locks don't artificially
/// split a continuous screen binge into fake pieces.
class StrainSessionDetail {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final List<AppUsageSnippet> apps;

  const StrainSessionDetail({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.apps = const [],
  });

  /// Formatted duration string (e.g., '48m', '1h 12m', '25m 10s')
  String get formattedDuration {
    if (durationSeconds <= 0) return '0s';
    final totalMinutes = durationSeconds ~/ 60;
    final remSeconds = durationSeconds % 60;

    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final remMinutes = totalMinutes % 60;
      if (remMinutes == 0) return '${hours}h';
      return '${hours}h ${remMinutes}m';
    }

    if (totalMinutes > 0) {
      if (remSeconds == 0) return '${totalMinutes}m';
      return '${totalMinutes}m ${remSeconds}s';
    }

    return '${remSeconds}s';
  }

  /// Formatted time window (e.g., '2:15 PM → 3:03 PM')
  String get timeWindowString {
    final start = _formatTime(startTime);
    final end = _formatTime(endTime);
    return '$start → $end';
  }

  /// Summary label of top app(s) used in this stretch
  String get topAppName {
    if (apps.isEmpty) return 'Phone';
    return apps.first.name;
  }

  /// Compact one-line summary for list cards showing only duration, start and end time (NO app name)
  /// e.g. '48m (2:15 PM → 3:03 PM)'
  String get summaryString {
    return '$formattedDuration ($timeWindowString)';
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  /// Calculates the single longest continuous screen strain session from a list of blocks.
  /// A phone rest interval breaks the strain session ONLY if it is >= [minRestThresholdSeconds]
  /// (the user's configured custom rest duration, e.g. 20s, 40s, 1m, 2m).
  /// Any rest shorter than this is insufficient to relieve eye strain and keeps the session unbroken!
  static StrainSessionDetail? calculateLongestStrain(
    List<ScreenActivityBlock> blocks, {
    int minRestThresholdSeconds = 20,
  }) {
    if (blocks.isEmpty) return null;

    final sorted = List<ScreenActivityBlock>.from(blocks)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    StrainSessionDetail? longest;
    DateTime? curStart;
    DateTime? curEnd;
    int curDurSec = 0;
    final Map<String, AppUsageSnippet> curApps = {};

    for (int i = 0; i < sorted.length; i++) {
      final b = sorted[i];

      if (b.isActiveScreen) {
        if (curStart == null) {
          curStart = b.startTime;
          curEnd = b.endTime;
          curDurSec = b.durationSeconds;
        } else {
          curEnd = b.endTime;
          curDurSec += b.durationSeconds;
        }

        for (final app in b.topApps) {
          final lower = app.name.toLowerCase().trim();
          if (lower == 'screen active' || lower == 'home screen' || lower.isEmpty) {
            continue;
          }
          final existing = curApps[app.name];
          if (existing != null) {
            curApps[app.name] = AppUsageSnippet(
              name: app.name,
              package: app.package.isNotEmpty ? app.package : existing.package,
              seconds: existing.seconds + app.seconds,
            );
          } else {
            curApps[app.name] = app;
          }
        }
      } else if (b.isPhoneRest) {
        // A rest breaks the session ONLY if it is >= minRestThresholdSeconds (custom rest duration)
        if (b.durationSeconds >= minRestThresholdSeconds) {
          if (curStart != null && curEnd != null && curDurSec > 0) {
            final appList = curApps.values.toList()
              ..sort((a, b) => b.seconds.compareTo(a.seconds));
            final session = StrainSessionDetail(
              startTime: curStart,
              endTime: curEnd,
              durationSeconds: curDurSec,
              apps: appList,
            );
            if (longest == null ||
                session.durationSeconds > longest.durationSeconds) {
              longest = session;
            }
          }
          curStart = null;
          curEnd = null;
          curDurSec = 0;
          curApps.clear();
        }
        // Rest duration < minRestThresholdSeconds: eyes did not rest sufficiently, session stays continuous!
      }
    }

    // Flush any pending session
    if (curStart != null && curEnd != null && curDurSec > 0) {
      final appList = curApps.values.toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));
      final session = StrainSessionDetail(
        startTime: curStart,
        endTime: curEnd,
        durationSeconds: curDurSec,
        apps: appList,
      );
      if (longest == null || session.durationSeconds > longest.durationSeconds) {
        longest = session;
      }
    }

    return longest;
  }
}

