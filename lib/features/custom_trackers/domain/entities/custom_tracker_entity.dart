/// TrackerType
///
/// Enumerates custom tracker tracking modes:
/// - count: Target based on repetitions or count (e.g., Push-ups, Glasses).
/// - timer: Target based on duration in minutes (e.g., Meditation, Reading).
enum TrackerType {
  count,
  timer,
}

/// CustomTrackerEntity
///
/// Domain entity representing a user-defined habit tracker with progress evaluation.
class CustomTrackerEntity {
  final String id;
  final String name;
  final TrackerType type;
  final int targetGoal;
  final int currentValueToday;
  final String unit;
  final int iconCodePoint;
  final int colorValue;
  final String reminderTime;
  final bool isReminderEnabled;
  final DateTime createdAt;

  const CustomTrackerEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.targetGoal,
    this.currentValueToday = 0,
    required this.unit,
    this.iconCodePoint = 0xe56c,
    this.colorValue = 0xFF10B981,
    this.reminderTime = '',
    this.isReminderEnabled = false,
    required this.createdAt,
  });

  /// Ratio of completion towards targetGoal (0.0 to 1.0)
  double get progressRatio {
    if (targetGoal <= 0) return 0.0;
    return (currentValueToday / targetGoal).clamp(0.0, 1.0);
  }

  /// Whether today's progress has met or exceeded targetGoal
  bool get isCompletedToday => currentValueToday >= targetGoal;

  CustomTrackerEntity copyWith({
    String? id,
    String? name,
    TrackerType? type,
    int? targetGoal,
    int? currentValueToday,
    String? unit,
    int? iconCodePoint,
    int? colorValue,
    String? reminderTime,
    bool? isReminderEnabled,
    DateTime? createdAt,
  }) {
    return CustomTrackerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetGoal: targetGoal ?? this.targetGoal,
      currentValueToday: currentValueToday ?? this.currentValueToday,
      unit: unit ?? this.unit,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      reminderTime: reminderTime ?? this.reminderTime,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'target_goal': targetGoal,
    'unit': unit,
    'icon_code_point': iconCodePoint,
    'color_value': colorValue,
    'reminder_time': reminderTime,
    'is_reminder_enabled': isReminderEnabled ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory CustomTrackerEntity.fromMap(
    Map<String, dynamic> map, {
    int currentValue = 0,
  }) {
    return CustomTrackerEntity(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] == 'timer' ? TrackerType.timer : TrackerType.count,
      targetGoal: (map['target_goal'] as num).toInt(),
      currentValueToday: currentValue,
      unit: map['unit'] as String? ?? '',
      iconCodePoint: (map['icon_code_point'] as num?)?.toInt() ?? 0xe56c,
      colorValue: (map['color_value'] as num?)?.toInt() ?? 0xFF10B981,
      reminderTime: map['reminder_time'] as String? ?? '',
      isReminderEnabled: (map['is_reminder_enabled'] as num?)?.toInt() == 1,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
