import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DeviceStateTracker
///
/// Service monitoring device usage states:
/// 1. Interactive screen state (Screen locked vs interactive)
/// 2. Proximity sensor (phone held to ear, face-down, or in pocket)
/// 3. Telephony state (in-call)
/// 4. Active media playback (video/movies)
/// 5. Touch interaction
class DeviceStateTracker {
  final ServiceInstance service;
  StreamSubscription? _callStateSubscription;
  StreamSubscription? _touchSubscription;
  StreamSubscription? _userNameSubscription;
  String? _userName;
  String? get userName => _userName;

  bool isInCall = false;
  bool isProximityNear = false;
  bool isScreenInteractive = true;
  bool isStationary = false;
  bool isMediaPlaying = false;
  DateTime? _lastTouchTime = DateTime.now();

  DeviceStateTracker(this.service) {
    _loadSavedSettings();
    _listenForSettingUpdates();
  }

  /// Whether the user has actively touched or scrolled within the last 3 seconds
  bool get isUserInteracting =>
      _lastTouchTime != null &&
      DateTime.now().difference(_lastTouchTime!).inSeconds < 3;

  /// Whether the phone is resting untouched, in pocket, screen is off, or user is not looking at it
  bool get isRestingUntouched {
    if (!isScreenInteractive || isInCall) {
      return true;
    }
    if (isProximityNear) {
      return true;
    }
    return false;
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name');
      if (savedName != null && savedName.trim().isNotEmpty) {
        _userName = savedName.trim();
      }
      await syncFromPreferences();
    } catch (_) {}
  }

  Future<void> syncFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final media = prefs.getBool('is_media_playing');
      if (media != null) isMediaPlaying = media;
      final screen = prefs.getBool('is_screen_interactive');
      if (screen != null) isScreenInteractive = screen;
      final prox = prefs.getBool('is_proximity_near');
      if (prox != null) isProximityNear = prox;
      final call = prefs.getBool('is_in_call');
      if (call != null) isInCall = call;
    } catch (_) {}
  }

  void _listenForSettingUpdates() {
    _touchSubscription = service.on('touch_interaction').listen((event) {
      if (event != null) {
        _lastTouchTime = DateTime.now();
      }
    });

    _callStateSubscription = service.on('call_state_update').listen((event) {
      if (event != null) {
        if (event['isInCall'] != null) {
          isInCall = event['isInCall'] as bool;
        }
        if (event['isProximityNear'] != null) {
          isProximityNear = event['isProximityNear'] as bool;
        }
        if (event['isScreenInteractive'] != null) {
          isScreenInteractive = event['isScreenInteractive'] as bool;
        }
        if (event['isMediaPlaying'] != null) {
          isMediaPlaying = event['isMediaPlaying'] as bool;
        }
      }
    });

    _userNameSubscription = service.on('update_user_name').listen((event) {
      if (event != null && event['name'] != null) {
        _userName = event['name'].toString().trim();
      }
    });
  }

  void start() {}

  void stop() {
    _touchSubscription?.cancel();
    _callStateSubscription?.cancel();
    _userNameSubscription?.cancel();
  }
}

