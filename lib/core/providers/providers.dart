import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../../features/eye_rest/domain/entities/eye_rest_entity.dart';
import '../../features/eye_rest/domain/usecases/track_screen_usage_usecase.dart';

import 'package:shared_preferences/shared_preferences.dart';

export '../../features/eye_rest/presentation/providers/daily_rhythm_provider.dart';
export '../../features/eye_rest/domain/entities/daily_rhythm_entity.dart';
export '../../features/eye_rest/domain/entities/screen_activity_block.dart';

// --- Database Provider ---
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

// --- 1. Eye Rest Riverpod Notifier ---
class EyeRestNotifier extends StateNotifier<EyeRestEntity> {
  final AppDatabase _db;
  final TrackScreenUsageUseCase _useCase = TrackScreenUsageUseCase();

  EyeRestNotifier(this._db) : super(EyeRestEntity.initial()) {
    _loadInitialState();
  }

  void _loadInitialState() {
    final today = DateTime.now();
    final breaksCount = _db.getTodayEyeBreaksCount(today);
    final y = today.year.toString().padLeft(4, '0');
    final m = today.month.toString().padLeft(2, '0');
    final d = today.day.toString().padLeft(2, '0');
    final todayStr = '$y-$m-$d';
    final summary = _db.getDailySummary(todayStr);
    final totalScreenSec = summary?.screenTimeSeconds ?? 0;

    final secStr = _db.getSetting('eye_interval_seconds');
    final enabledStr = _db.getSetting('eye_is_enabled');
    final styleStr = _db.getSetting('eye_break_style');
    final gamingStr = _db.getSetting('eye_gaming_defense');

    int intervalSec = 1200; // default 20 min (1200 seconds)
    if (secStr != null) {
      final parsed = int.tryParse(secStr);
      if (parsed != null && parsed >= 60 && parsed <= 7200) {
        intervalSec = parsed;
      } else {
        _db.setSetting('eye_interval_seconds', '1200');
        _db.setSetting('eye_interval_minutes', '20');
      }
    }
    final isEnabled = enabledStr != null ? enabledStr == 'true' : true;
    final breakStyle = styleStr ?? 'floating';
    final isGamingDefense = gamingStr != 'false';

    state = state.copyWith(
      breaksTakenToday: breaksCount,
      totalDailyScreenSeconds: totalScreenSec,
      intervalSeconds: intervalSec,
      isEnabled: isEnabled,
      breakStyle: breakStyle,
      isGamingDefenseEnabled: isGamingDefense,
    );

    syncFromStorage();
  }

  /// Synchronizes breaks taken and daily totals with SharedPreferences
  Future<void> syncFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString('eye_breaks_today_date') ?? '';

      // Only rollover if savedDate is explicitly from a PREVIOUS day (e.g. yesterday)
      if (savedDate.isNotEmpty && savedDate != todayStr) {
        prefs.setString('eye_breaks_today_date', todayStr);
        prefs.setInt('eye_breaks_today_count', 0);
        prefs.setInt('total_daily_screen_seconds', 0);
        prefs.setInt('continuous_screen_seconds', 0);
        state = state.copyWith(
          breaksTakenToday: 0,
          totalDailyScreenSeconds: 0,
          currentScreenSeconds: 0,
        );
        return;
      }

      // If today or first initialization:
      prefs.setString('eye_breaks_today_date', todayStr);
      final prefsBreaks = prefs.getInt('eye_breaks_today_count') ?? 0;
      final dbBreaks = _db.getTodayEyeBreaksCount(DateTime.now());

      if (prefsBreaks > dbBreaks) {
        final diff = prefsBreaks - dbBreaks;
        for (int i = 0; i < diff; i++) {
          _db.insertEyeBreak(DateTime.now());
        }
      }
      final maxBreaks = max(max(prefsBreaks, dbBreaks), state.breaksTakenToday);
      final prefsScreenSec = max(
        prefs.getInt('total_daily_screen_seconds') ?? 0,
        prefs.getInt('rhythm_active_screen_seconds') ?? 0,
      );
      final continuousSec = max(
        prefs.getInt('continuous_screen_seconds') ?? 0,
        prefs.getInt('rhythm_current_session_seconds') ?? 0,
      );

      final effectiveTotalDaily = max(
        prefsScreenSec,
        state.totalDailyScreenSeconds,
      );
      final effectiveContinuous = continuousSec > 0
          ? max(continuousSec, state.currentScreenSeconds)
          : state.currentScreenSeconds;

      state = state.copyWith(
        breaksTakenToday: maxBreaks,
        totalDailyScreenSeconds: effectiveTotalDaily,
        currentScreenSeconds: effectiveContinuous,
      );

      final prefsSec = prefs.getInt('eye_interval_seconds');
      if (prefsSec != null && prefsSec >= 60 && prefsSec != state.intervalSeconds) {
        state = state.copyWith(intervalSeconds: prefsSec);
      } else if (prefsSec != null && prefsSec < 60) {
        prefs.setInt('eye_interval_seconds', 1200);
        prefs.setInt('eye_interval_minutes', 20);
        state = state.copyWith(intervalSeconds: 1200);
      }

      final rhythmTarget = prefs.getInt('rhythm_cycle_target_seconds');
      if (rhythmTarget != null && rhythmTarget < 60) {
        prefs.setInt('rhythm_cycle_target_seconds', 1200);
      }

      // Ensure storage holds the reconciled values
      prefs.setInt('total_daily_screen_seconds', effectiveTotalDaily);
      prefs.setInt('continuous_screen_seconds', effectiveContinuous);
      prefs.setInt('eye_breaks_today_count', maxBreaks);
    } catch (_) {}
  }

  void onScreenTick(int seconds, {bool isInCall = false}) {
    if (!state.isEnabled || isInCall) return;
    state = _useCase.onScreenTick(state, seconds, isInCall: isInCall);
    if (state.totalDailyScreenSeconds % 5 == 0) {
      SharedPreferences.getInstance()
          .then((prefs) {
            prefs.setInt(
              'total_daily_screen_seconds',
              state.totalDailyScreenSeconds,
            );
            prefs.setInt(
              'continuous_screen_seconds',
              state.currentScreenSeconds,
            );
          })
          .catchError((_) {});
    }
  }

  void onInactivity(int idleSeconds) {
    final prevBreaks = state.breaksTakenToday;
    state = _useCase.onInactivity(state, idleSeconds);
    if (state.breaksTakenToday > prevBreaks) {
      _db.insertEyeBreak(DateTime.now());
    }
  }

  void recordAutoBreak({int? breaksCount}) {
    _db.insertEyeBreak(DateTime.now());
    final dbCount = _db.getTodayEyeBreaksCount(DateTime.now());
    final effectiveCount = breaksCount != null && breaksCount > dbCount
        ? breaksCount
        : dbCount;

    state = state.copyWith(
      currentScreenSeconds: 0,
      breaksTakenToday: effectiveCount,
      sessionStartTime: DateTime.now(),
    );
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('continuous_screen_seconds', 0);
        prefs.setInt('eye_breaks_today_count', effectiveCount);
      });
    } catch (_) {}
  }

  void takeBreak() {
    _db.insertEyeBreak(DateTime.now());
    final breaksCount = _db.getTodayEyeBreaksCount(DateTime.now());
    state = state.copyWith(
      currentScreenSeconds: 0,
      breaksTakenToday: breaksCount,
      sessionStartTime: DateTime.now(),
    );
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('continuous_screen_seconds', 0);
        prefs.setInt('eye_breaks_today_count', breaksCount);
      });
    } catch (_) {}
    FlutterBackgroundService().invoke('update_eye_settings', {
      'reset': true,
      'breaksCount': breaksCount,
    });
  }

  void setIntervalSeconds(int seconds) {
    _db.setSetting('eye_interval_seconds', seconds.toString());
    _db.setSetting('eye_interval_minutes', (seconds ~/ 60).toString());
    state = state.copyWith(intervalSeconds: seconds);
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setInt('eye_interval_seconds', seconds);
          prefs.setInt('eye_interval_minutes', seconds ~/ 60);
        })
        .catchError((_) {});
    FlutterBackgroundService().invoke('update_eye_settings', {
      'intervalSeconds': seconds,
      'isSeconds': false,
      'reset': true,
    });
  }

  void setInterval(int intervalMinutes) {
    setIntervalSeconds(intervalMinutes * 60);
  }

  void toggleEnabled(bool enabled) {
    _db.setSetting('eye_is_enabled', enabled.toString());
    state = state.copyWith(isEnabled: enabled);
    FlutterBackgroundService().invoke('update_eye_settings', {
      'isEnabled': enabled,
    });
  }

  void setBreakStyle(String style) {
    _db.setSetting('eye_break_style', style);
    state = state.copyWith(breakStyle: style);
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setString('eye_break_style', style);
        })
        .catchError((_) {});
  }

  void setGamingDefenseEnabled(bool enabled) {
    _db.setSetting('eye_gaming_defense', enabled.toString());
    state = state.copyWith(isGamingDefenseEnabled: enabled);
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setBool('eye_gaming_defense', enabled);
        })
        .catchError((_) {});
    FlutterBackgroundService().invoke('update_eye_settings', {
      'isGamingDefense': enabled,
    });
  }

  Future<void> setOverlayEnabled(bool enabled) async {}

  void setScreenMetrics({
    required int currentSeconds,
    int? totalDailySeconds,
    int? breaksCount,
    bool? isMediaPlaying,
  }) {
    int updatedBreaks = state.breaksTakenToday;
    if (breaksCount != null && breaksCount > state.breaksTakenToday) {
      updatedBreaks = breaksCount;
      _db.insertEyeBreak(DateTime.now());
    }

    final effectiveDailySeconds = max(
      totalDailySeconds ?? state.totalDailyScreenSeconds,
      state.totalDailyScreenSeconds,
    );

    state = state.copyWith(
      currentScreenSeconds: currentSeconds,
      breaksTakenToday: updatedBreaks,
      totalDailyScreenSeconds: effectiveDailySeconds,
      isMediaPlaying: isMediaPlaying ?? state.isMediaPlaying,
    );
  }
}

final eyeRestProvider = StateNotifierProvider<EyeRestNotifier, EyeRestEntity>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return EyeRestNotifier(db);
});

