import 'dart:convert';

/// ActivityType
///
/// Physical reality classification for device activity:
/// - activeScreen: Display ON = Active Screen Time (Slate / Neutral)
/// - phoneRest: Display OFF / Locked = Phone Rest (Soft Mint / Green)
enum ActivityType {
  activeScreen,
  phoneRest,
}

/// AppUsageSnippet
///
/// Represents an application used during an active screen block.
class AppUsageSnippet {
  final String name;
  final String package;
  final int seconds;

  const AppUsageSnippet({
    required this.name,
    required this.package,
    required this.seconds,
  });

  String get formattedDuration {
    final m = seconds ~/ 60;
    if (m == 0) return '${seconds}s';
    final rem = seconds % 60;
    if (rem == 0) return '${m}m';
    return '${m}m ${rem}s';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'package': package,
        'seconds': seconds,
      };

  factory AppUsageSnippet.fromMap(Map<String, dynamic> map) => AppUsageSnippet(
        name: map['name'] as String? ?? 'App',
        package: map['package'] as String? ?? '',
        seconds: (map['seconds'] as num?)?.toInt() ?? 0,
      );
}

/// ScreenActivityBlock
///
/// Represents an immutable continuous block of device screen time or rest.
/// Enriched with Storyboard context: top apps used, background audio, and overrun flags.
class ScreenActivityBlock {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final ActivityType type;
  final List<AppUsageSnippet> topApps;
  final bool hasBackgroundAudio;
  final String audioAppName;
  final bool isOverrun;

  const ScreenActivityBlock({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.topApps = const [],
    this.hasBackgroundAudio = false,
    this.audioAppName = '',
    this.isOverrun = false,
  });

  Duration get duration => endTime.difference(startTime);
  int get durationSeconds => duration.inSeconds;

  bool get isActiveScreen => type == ActivityType.activeScreen;
  bool get isPhoneRest => type == ActivityType.phoneRest;

  ScreenActivityBlock copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    ActivityType? type,
    List<AppUsageSnippet>? topApps,
    bool? hasBackgroundAudio,
    String? audioAppName,
    bool? isOverrun,
  }) {
    return ScreenActivityBlock(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      topApps: topApps ?? this.topApps,
      hasBackgroundAudio: hasBackgroundAudio ?? this.hasBackgroundAudio,
      audioAppName: audioAppName ?? this.audioAppName,
      isOverrun: isOverrun ?? this.isOverrun,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_screen_on': isActiveScreen ? 1 : 0,
        if (topApps.isNotEmpty)
          'top_apps_json': jsonEncode(topApps.map((a) => a.toMap()).toList()),
        'has_bg_audio': hasBackgroundAudio ? 1 : 0,
        'audio_app': audioAppName,
      };

  factory ScreenActivityBlock.fromMap(Map<String, dynamic> map) {
    List<AppUsageSnippet> apps = [];
    final appsJson = map['top_apps_json'] as String?;
    if (appsJson != null && appsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(appsJson) as List;
        apps = decoded
            .map((item) => AppUsageSnippet.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return ScreenActivityBlock(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String).toLocal(),
      endTime: DateTime.parse(map['end_time'] as String).toLocal(),
      type: (map['is_screen_on'] as int) == 1
          ? ActivityType.activeScreen
          : ActivityType.phoneRest,
      topApps: apps,
      hasBackgroundAudio: (map['has_bg_audio'] as int?) == 1,
      audioAppName: map['audio_app'] as String? ?? '',
      isOverrun: (map['is_screen_on'] as int) == 1 &&
          DateTime.parse(map['end_time'] as String)
                  .difference(DateTime.parse(map['start_time'] as String))
                  .inMinutes >=
              35,
    );
  }

  @override
  String toString() {
    return 'ScreenActivityBlock(type: $type, ${startTime.toIso8601String().substring(11, 19)} - ${endTime.toIso8601String().substring(11, 19)}, apps: ${topApps.length})';
  }
}
