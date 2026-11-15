import 'dart:math';

/// EyeRestEntity
///
/// Domain entity representing the state and user preferences
/// for the Eye Strain / 20-20-20 screen rest feature.
class EyeRestEntity {
  /// Whether eye break reminders and continuous screen tracking are active
  final bool isEnabled;

  /// Continuous screen-on duration interval in seconds before triggering an eye break
  /// (e.g. 20s for fast testing, 300s for 5 min, 600s for 10 min, etc.)
  final int intervalSeconds;

  /// Continuous screen-on duration interval in minutes (returns 1 for fast testing seconds)
  final int intervalMinutes;


  /// Whether fast 20-second testing mode is active
  bool get isTest20s => intervalSeconds == 20;

  /// Current continuous screen-on duration in seconds
  final int currentScreenSeconds;

  /// Cumulative total screen-on duration accumulated today in seconds
  final int totalDailyScreenSeconds;

  /// Number of eye breaks completed today (both automatic after 20+s rest and manual)
  final int breaksTakenToday;

  /// Timestamp when the current screen session began
  final DateTime? sessionStartTime;

  /// Timestamp when the screen was last locked (for short reopen detection)
  final DateTime? lastLockedTime;

  /// Whether video/movie/media playback is actively running on device
  final bool isMediaPlaying;

  /// Eye break alert style: 'fullscreen' or 'floating'
  final String breakStyle;

  /// Smart Gaming Defense (Strategy 3): automatically use non-blocking mini indicator during gaming
  final bool isGamingDefenseEnabled;

  /// Whether the native floating pill overlay over other third-party apps is enabled
  final bool isOverlayEnabled;

  const EyeRestEntity({
    required this.isEnabled,
    this.intervalSeconds = 300,
    this.intervalMinutes = 5,
    required this.currentScreenSeconds,
    this.totalDailyScreenSeconds = 0,
    this.breaksTakenToday = 0,
    this.sessionStartTime,
    this.lastLockedTime,
    this.isMediaPlaying = false,
    this.breakStyle = 'floating',
    this.isGamingDefenseEnabled = true,
    this.isOverlayEnabled = false,
  });

  /// Factory constructor providing standard healthy defaults (5 min interval)
  factory EyeRestEntity.initial() {
    return const EyeRestEntity(
      isEnabled: true,
      intervalSeconds: 300,
      intervalMinutes: 5,
      currentScreenSeconds: 0,
      totalDailyScreenSeconds: 0,
      breaksTakenToday: 0,
      sessionStartTime: null,
      lastLockedTime: null,
      isMediaPlaying: false,
      breakStyle: 'floating',
      isGamingDefenseEnabled: true,
      isOverlayEnabled: false,
    );
  }

  /// Calculates the progress percentage (0.0 to 1.0) towards the next eye break
  double get progress {
    if (intervalSeconds <= 0) return 0.0;
    return (currentScreenSeconds / intervalSeconds).clamp(0.0, 1.0);
  }

  /// Recommended number of breaks based on total daily screen time and configured interval
  int get recommendedBreaks {
    final sec = max(1, intervalSeconds);
    if (totalDailyScreenSeconds == 0) return 1;
    final count = (totalDailyScreenSeconds / sec).ceil();
    return max(1, count);
  }

  /// Formats the continuous screen timer in mm:ss format
  String get screenTimeFormatted {
    final minutes = currentScreenSeconds ~/ 60;
    final seconds = currentScreenSeconds % 60;
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  /// Formats total daily screen time in clean readable format (e.g. "1h 24m" or "45m")
  String get totalDailyScreenFormatted {
    final totalMins = totalDailyScreenSeconds ~/ 60;
    if (totalMins < 60) {
      return '$totalMins min';
    }
    final hours = totalMins ~/ 60;
    final remainingMins = totalMins % 60;
    return '${hours}h ${remainingMins}m';
  }

  /// Whether the user has exceeded their continuous screen-on threshold
  bool get shouldTriggerBreak {
    return currentScreenSeconds >= intervalSeconds;
  }

  /// Returns a copy of the entity with updated fields
  EyeRestEntity copyWith({
    bool? isEnabled,
    int? intervalMinutes,
    int? intervalSeconds,
    int? currentScreenSeconds,
    int? totalDailyScreenSeconds,
    int? breaksTakenToday,
    DateTime? sessionStartTime,
    DateTime? lastLockedTime,
    bool? isMediaPlaying,
    String? breakStyle,
    bool? isGamingDefenseEnabled,
    bool? isOverlayEnabled,
  }) {
    final int newSeconds =
        intervalSeconds ??
        (intervalMinutes != null
            ? (intervalMinutes == 20 && this.intervalSeconds == 20
                  ? 20
                  : intervalMinutes * 60)
            : this.intervalSeconds);
    final int newMinutes = newSeconds < 60
        ? (newSeconds / 60).ceil()
        : newSeconds ~/ 60;

    return EyeRestEntity(
      isEnabled: isEnabled ?? this.isEnabled,
      intervalSeconds: newSeconds,
      intervalMinutes: newMinutes,
      currentScreenSeconds: currentScreenSeconds ?? this.currentScreenSeconds,
      totalDailyScreenSeconds:
          totalDailyScreenSeconds ?? this.totalDailyScreenSeconds,
      breaksTakenToday: breaksTakenToday ?? this.breaksTakenToday,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      lastLockedTime: lastLockedTime ?? this.lastLockedTime,
      isMediaPlaying: isMediaPlaying ?? this.isMediaPlaying,
      breakStyle: breakStyle ?? this.breakStyle,
      isGamingDefenseEnabled:
          isGamingDefenseEnabled ?? this.isGamingDefenseEnabled,
      isOverlayEnabled: isOverlayEnabled ?? this.isOverlayEnabled,
    );
  }
}
