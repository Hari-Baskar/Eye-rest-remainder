/// CallStateEntity
///
/// Domain entity representing phone call activity and ear proximity status.
/// When in a call or holding the phone against the ear, eye rest alerts and
/// screen strain timers are paused to avoid false positives and intrusive sounds.
class CallStateEntity {
  /// Whether an active phone call is currently taking place
  final bool isInCall;

  /// Whether the proximity sensor detects the phone is near the ear / face / inside pocket
  final bool isProximityNear;

  /// Whether the device screen is active and interactive (true = display on, false = display off/locked)
  final bool isScreenInteractive;

  /// Whether active video/movie/media playback is playing on device
  final bool isMediaPlaying;

  const CallStateEntity({
    required this.isInCall,
    required this.isProximityNear,
    this.isScreenInteractive = true,
    this.isMediaPlaying = false,
  });

  /// Factory constructor for default state (not on call, phone away from ear, screen on)
  factory CallStateEntity.initial() {
    return const CallStateEntity(
      isInCall: false,
      isProximityNear: false,
      isScreenInteractive: true,
      isMediaPlaying: false,
    );
  }

  /// Whether notifications and timers should be silenced/paused
  bool get shouldMuteTracking => isInCall || isProximityNear || !isScreenInteractive;

  /// Returns a copy with updated call, proximity, or media state
  CallStateEntity copyWith({
    bool? isInCall,
    bool? isProximityNear,
    bool? isScreenInteractive,
    bool? isMediaPlaying,
  }) {
    return CallStateEntity(
      isInCall: isInCall ?? this.isInCall,
      isProximityNear: isProximityNear ?? this.isProximityNear,
      isScreenInteractive: isScreenInteractive ?? this.isScreenInteractive,
      isMediaPlaying: isMediaPlaying ?? this.isMediaPlaying,
    );
  }
}
