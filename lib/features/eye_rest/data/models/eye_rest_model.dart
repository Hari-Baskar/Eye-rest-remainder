import '../../domain/entities/eye_rest_entity.dart';

/// EyeRestModel
///
/// Data transfer model extending [EyeRestEntity] with JSON serialization
/// to persist and restore eye break preferences from local storage.
class EyeRestModel extends EyeRestEntity {
  const EyeRestModel({
    required super.isEnabled,
    required super.intervalMinutes,
    required super.currentScreenSeconds,
    super.breaksTakenToday = 0,
    super.sessionStartTime,
    super.lastLockedTime,
  });

  /// Constructs an [EyeRestModel] from a Map / JSON
  factory EyeRestModel.fromJson(Map<String, dynamic> json) {
    return EyeRestModel(
      isEnabled: json['isEnabled'] as bool? ?? true,
      intervalMinutes: json['intervalMinutes'] as int? ?? 20,
      currentScreenSeconds: json['currentScreenSeconds'] as int? ?? 0,
      breaksTakenToday: json['breaksTakenToday'] as int? ?? 0,
      sessionStartTime: json['sessionStartTime'] != null
          ? DateTime.tryParse(json['sessionStartTime'] as String)
          : null,
      lastLockedTime: json['lastLockedTime'] != null
          ? DateTime.tryParse(json['lastLockedTime'] as String)
          : null,
    );
  }

  /// Converts the model into a JSON Map
  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'intervalMinutes': intervalMinutes,
      'currentScreenSeconds': currentScreenSeconds,
      'breaksTakenToday': breaksTakenToday,
      'sessionStartTime': sessionStartTime?.toIso8601String(),
      'lastLockedTime': lastLockedTime?.toIso8601String(),
    };
  }

  /// Converts an [EyeRestEntity] to an [EyeRestModel]
  factory EyeRestModel.fromEntity(EyeRestEntity entity) {
    return EyeRestModel(
      isEnabled: entity.isEnabled,
      intervalMinutes: entity.intervalMinutes,
      currentScreenSeconds: entity.currentScreenSeconds,
      breaksTakenToday: entity.breaksTakenToday,
      sessionStartTime: entity.sessionStartTime,
      lastLockedTime: entity.lastLockedTime,
    );
  }
}
