import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/notification_service.dart';
import 'device_state_tracker.dart';

/// initializeService
///
/// Pure Event-Driven Model:
/// Eliminates the continuous foreground service, status bar icon, and 1-second busy loop.
/// Cleans up any previously running background service instance.
Future<void> initializeService() async {
  await NotificationService.initialize();

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: false,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  try {
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stopService');
    }
  } catch (_) {}
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Initialize and start DeviceStateTracker
  final tracker = DeviceStateTracker(service);
  tracker.start();

  // Unified background timer for Eye Strain, Hydration, and Movement
  int screenSeconds = 0;
  int lastActiveSessionSeconds = 0;
  int totalDailyScreenSeconds = 0;
  int eyeIdleSeconds = 0;
  int breaksTakenToday = 0;
  bool hasAwardedBreakForCurrentIdle = false;
  int eyeBreakIntervalSeconds = 300;
  int requiredRestSeconds = 120;
  bool isEyeBreakEnabled = true;
  bool isOverlayEnabled = false;
  bool isGamingDefense = true;
  int lastAlertScreenSeconds = 0;

  String currentUserName = 'LifeMint';
  SharedPreferences? prefsInstance;
  try {
    prefsInstance = await SharedPreferences.getInstance();
    final prefs = prefsInstance;
    currentUserName = prefs.getString('user_name') ?? 'LifeMint';
    eyeBreakIntervalSeconds = prefs.getInt('eye_interval_seconds') ?? 1200;
    if (eyeBreakIntervalSeconds < 60) {
      eyeBreakIntervalSeconds = 1200;
      prefs.setInt('eye_interval_seconds', 1200);
    }
    isEyeBreakEnabled =
        prefs.getBool('eye_is_enabled') ??
        prefs.getBool('is_eye_enabled') ??
        true;
    isOverlayEnabled = prefs.getBool('is_overlay_enabled') ?? false;
    isGamingDefense = prefs.getBool('eye_gaming_defense') ?? true;
    final savedRest = prefs.getInt('rhythm_required_rest_seconds') ?? prefs.getInt('eye_rest_duration_seconds');
    if (savedRest != null && savedRest > 0) {
      requiredRestSeconds = savedRest;
    }

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('eye_breaks_today_date') ?? '';
    if (savedDate == todayStr) {
      breaksTakenToday = prefs.getInt('eye_breaks_today_count') ?? 0;
      totalDailyScreenSeconds = prefs.getInt('total_daily_screen_seconds') ?? 0;
      screenSeconds = prefs.getInt('continuous_screen_seconds') ?? 0;
      lastActiveSessionSeconds = screenSeconds;
    } else {
      breaksTakenToday = 0;
      totalDailyScreenSeconds = 0;
      screenSeconds = 0;
      prefs.setString('eye_breaks_today_date', todayStr);
      prefs.setInt('eye_breaks_today_count', 0);
      prefs.setInt('total_daily_screen_seconds', 0);
      prefs.setInt('continuous_screen_seconds', 0);
    }
  } catch (_) {}

  service.on('update_eye_settings').listen((event) async {
    if (event != null) {
      if (event['intervalSeconds'] != null) {
        final parsed = (event['intervalSeconds'] as num).toInt();
        eyeBreakIntervalSeconds = parsed >= 60 ? parsed : 1200;
      } else if (event['interval'] != null) {
        final val = (event['interval'] as num).toInt();
        eyeBreakIntervalSeconds = val >= 1 ? val * 60 : 1200;
      }
      if (event['isEnabled'] != null) {
        isEyeBreakEnabled = event['isEnabled'] as bool;
      }
      if (event['isOverlayEnabled'] != null) {
        isOverlayEnabled = event['isOverlayEnabled'] as bool;
      }
      if (event['isGamingDefense'] != null) {
        isGamingDefense = event['isGamingDefense'] as bool;
      }
      if (event['breaksCount'] != null) {
        breaksTakenToday = (event['breaksCount'] as num).toInt();
      }
      if (event['restSeconds'] != null) {
        final r = (event['restSeconds'] as num).toInt();
        if (r > 0) requiredRestSeconds = r;
      }
      if (event['totalDailySeconds'] != null) {
        final synced = (event['totalDailySeconds'] as num).toInt();
        if (synced > totalDailyScreenSeconds) {
          totalDailyScreenSeconds = synced;
        }
      }
      if (event['reset'] == true) {
        screenSeconds = 0;
        eyeIdleSeconds = 0;
        lastActiveSessionSeconds = 0;
        lastAlertScreenSeconds = 0;
        hasAwardedBreakForCurrentIdle = false;
        try {
          final prefs = prefsInstance ?? await SharedPreferences.getInstance();
          prefs.setInt('continuous_screen_seconds', 0);
        } catch (_) {}
      }
      try {
        final prefs = prefsInstance ?? await SharedPreferences.getInstance();

        prefs.setBool('eye_is_enabled', isEyeBreakEnabled);
        prefs.setBool('is_eye_enabled', isEyeBreakEnabled);
        prefs.setInt('eye_breaks_today_count', breaksTakenToday);
        prefs.setInt('total_daily_screen_seconds', totalDailyScreenSeconds);
      } catch (_) {}
    }
  });

  service.on('app_lifecycle').listen((event) {
    if (event != null && event['state'] != null) {
      final stateStr = event['state'].toString();
      if (stateStr == 'resumed') {
        eyeIdleSeconds = 0;
      }
    }
  });

  service.on('touch_interaction').listen((event) {
    eyeIdleSeconds = 0;
    hasAwardedBreakForCurrentIdle = false;
  });

  service.on('update_user_name').listen((event) async {
    if (event != null && event['name'] != null) {
      currentUserName = event['name'].toString().trim();
      try {
        final prefs = prefsInstance ?? await SharedPreferences.getInstance();
        prefs.setString('user_name', currentUserName);
      } catch (_) {}
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '$currentUserName • Wellness Active',
          content:
              'Monitoring screen time & wellness for $currentUserName',
        );
      }
    }
  });

  int ticksCount = 0;
  String currentTrackingDateStr = DateTime.now().toIso8601String().substring(
    0,
    10,
  );

  // Ticks every second in background
  // Ticks every second in background
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      ticksCount++;

      // Midnight rollover check: reset daily metrics if date changes while background service is running
      final nowDayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (nowDayStr != currentTrackingDateStr) {
        currentTrackingDateStr = nowDayStr;
        totalDailyScreenSeconds = 0;
        breaksTakenToday = 0;
        screenSeconds = 0;
        eyeIdleSeconds = 0;
        hasAwardedBreakForCurrentIdle = false;
        try {
          prefsInstance?.setString('eye_breaks_today_date', nowDayStr);
          prefsInstance?.setInt('eye_breaks_today_count', 0);
          prefsInstance?.setInt('total_daily_screen_seconds', 0);
          prefsInstance?.setInt('continuous_screen_seconds', 0);
        } catch (_) {}
      }

      // Periodically sync hardware/screen state and break completion from SharedPreferences (every 2 seconds)
      if (ticksCount % 2 == 0) {
        await tracker.syncFromPreferences();
        if (prefsInstance != null) {
          try {
            await prefsInstance.reload();
            final savedContinuous = prefsInstance.getInt(
              'continuous_screen_seconds',
            );
            if (savedContinuous == 0 && screenSeconds > 0) {
              screenSeconds = 0;
              lastAlertScreenSeconds = 0;
            }
            final savedBreaks = prefsInstance.getInt('eye_breaks_today_count');
            if (savedBreaks != null && savedBreaks > breaksTakenToday) {
              breaksTakenToday = savedBreaks;
            }
          } catch (_) {}
        }
      }

      // 1. Eye Break Tracking (Smart Screen & Video Watching Detection)
      if (isEyeBreakEnabled) {
        // Resting check: Screen locked/off, in-call, proximity covered, OR stationary on table with no touches and no video
        final isStationaryUntouched = tracker.isStationary && !tracker.isMediaPlaying && !tracker.isUserInteracting;
        final isResting = tracker.isRestingUntouched || isStationaryUntouched;

        if (isResting) {
          // Untouched on table/desk, screen locked, in pocket, or walking without screen
          eyeIdleSeconds++;

          // If screen was active before resting, preserve duration to qualify for break
          if (screenSeconds > 0) {
            lastActiveSessionSeconds = screenSeconds;
          }

          // Configurable continuous seconds of true resting qualifies for an automatic completed break
          final effectiveRestThreshold = requiredRestSeconds > 0 ? requiredRestSeconds : 20;
          if (eyeIdleSeconds >= effectiveRestThreshold && !hasAwardedBreakForCurrentIdle) {
            hasAwardedBreakForCurrentIdle = true;
            if (lastActiveSessionSeconds >= effectiveRestThreshold || screenSeconds >= effectiveRestThreshold) {
              breaksTakenToday++;

              try {
                final todayStr = DateTime.now().toIso8601String().substring(
                  0,
                  10,
                );
                prefsInstance?.setInt(
                  'eye_breaks_today_count',
                  breaksTakenToday,
                );
                prefsInstance?.setString('eye_breaks_today_date', todayStr);
                prefsInstance?.setInt(
                  'eye_last_break_time_ms',
                  DateTime.now().millisecondsSinceEpoch,
                );
              } catch (_) {}

              service.invoke('eye_break_auto_completed', {
                'sessionSeconds': lastActiveSessionSeconds,
                'breaksCount': breaksTakenToday,
              });
            }
            // Reset continuous session timer immediately
            screenSeconds = 0;
            lastActiveSessionSeconds = 0;
            eyeIdleSeconds = 0;
            lastAlertScreenSeconds = 0;
            try {
              prefsInstance?.setInt('continuous_screen_seconds', 0);
            } catch (_) {}
          }
        } else {
          // Active visual usage: screen is interactive and user is engaging with device or watching movie
          eyeIdleSeconds = 0;
          hasAwardedBreakForCurrentIdle = false;
          screenSeconds++;
          totalDailyScreenSeconds++;
          lastActiveSessionSeconds = screenSeconds;

          // Periodically save continuous screen seconds to SharedPreferences (every 3 seconds)
          if (ticksCount % 3 == 0 && prefsInstance != null) {
            try {
              prefsInstance.setInt('continuous_screen_seconds', screenSeconds);
              final saved =
                  prefsInstance.getInt('total_daily_screen_seconds') ?? 0;
              if (totalDailyScreenSeconds > saved) {
                prefsInstance.setInt(
                  'total_daily_screen_seconds',
                  totalDailyScreenSeconds,
                );
              }
            } catch (_) {}
          }

          final targetSeconds = eyeBreakIntervalSeconds >= 60 ? eyeBreakIntervalSeconds : 1200;
          if (screenSeconds >= targetSeconds &&
              (lastAlertScreenSeconds == 0 ||
                  (screenSeconds - lastAlertScreenSeconds >= targetSeconds))) {
            lastAlertScreenSeconds = screenSeconds;
            final breakStyle =
                prefsInstance?.getString('eye_break_style') ?? 'floating';
            final durationVal = targetSeconds ~/ 60;
            final restSec = prefsInstance?.getInt('eye_rest_duration_seconds') ??
                prefsInstance?.getInt('rhythm_required_rest_seconds') ??
                requiredRestSeconds;
            NotificationService.showEyeBreakAlert(
              durationVal > 0 ? durationVal : 20,
              userName: currentUserName,
              isSeconds: false,
              restSeconds: restSec,
              breakStyle: breakStyle,
              isGamingDefense: isGamingDefense,
              isOverlayEnabled: isOverlayEnabled,
              isMediaPlaying: tracker.isMediaPlaying,
            );
          }
        }

        // Persist daily total periodically every 15 seconds synchronously
        if (ticksCount % 15 == 0 && prefsInstance != null) {
          try {
            final saved =
                prefsInstance.getInt('total_daily_screen_seconds') ?? 0;
            if (saved > totalDailyScreenSeconds) {
              totalDailyScreenSeconds = saved;
            } else if (totalDailyScreenSeconds > saved) {
              prefsInstance.setInt(
                'total_daily_screen_seconds',
                totalDailyScreenSeconds,
              );
            }
          } catch (_) {}
        }

        service.invoke('screen_time_tick', {
          'seconds': screenSeconds,
          'totalDailySeconds': totalDailyScreenSeconds,
          'idleSeconds': eyeIdleSeconds,
          'breaksCount': breaksTakenToday,
          'isMediaPlaying': tracker.isMediaPlaying,
          'isResting': isResting,
        });
      }
    } catch (_) {}
  });
}
