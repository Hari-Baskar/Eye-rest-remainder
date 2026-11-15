import 'dart:async';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/providers.dart' show databaseProvider;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/daily_rhythm_entity.dart';
import '../../domain/entities/screen_activity_block.dart';
import '../../domain/usecases/track_device_activity_usecase.dart';
import '../../../../core/services/system_screen_time_service.dart';
import '../../../progress/domain/entities/strain_session_detail.dart';

/// DailyRhythmNotifier
///
/// Riverpod StateNotifier managing the "Pure Device Activity + Gentle Delivery" cumulative model:
/// - Cumulative continuous screen timer (increments past 20m -> 40m -> 60m until rest taken).
/// - Customizable Continuous Screen Target (e.g. 20m, 30m, 45m, or custom).
/// - Customizable Required Rest Duration (e.g. 20s, 1m, 2m, or custom).
/// - Real-time Storyboard extraction with per-app usage and background audio.
/// - Timer Respect Rate & compliance tracking.
class DailyRhythmNotifier extends StateNotifier<DailyRhythmEntity> {
  final AppDatabase _db;
  final TrackDeviceActivityUseCase _useCase = TrackDeviceActivityUseCase();

  Timer? _autoDismissTimer;
  int? _activeBlockId;
  int _tickCount = 0;

  DailyRhythmNotifier(this._db) : super(DailyRhythmEntity.initial()) {
    _loadTodayData();
  }

  /// Loads today's persisted activity blocks and reminder count from SQLite
  Future<void> _loadTodayData() async {
    final now = DateTime.now();
    final blocks = _db.getTodayActivityBlocks(now);
    final dbReminders = _db.getTodayGentleRemindersCount(now);

    int totalActive = 0;
    int totalRest = 0;

    for (final b in blocks) {
      if (b.isActiveScreen) {
        totalActive += b.durationSeconds;
      } else {
        totalRest += b.durationSeconds;
      }
    }

    // Read saved continuous screen seconds, custom targets, and calculate elapsed time if killed
    int savedSession = 0;
    int targetSec = TrackDeviceActivityUseCase.kDefaultCycleSeconds;
    int restSec = TrackDeviceActivityUseCase.kDefaultRestThresholdSeconds;
    int calculatedSession = 0;
    int reminders = dbReminders;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      savedSession =
          prefs.getInt('rhythm_current_session_seconds') ??
          prefs.getInt('continuous_screen_seconds') ??
          0;
      final savedActive =
          prefs.getInt('rhythm_active_screen_seconds') ??
          prefs.getInt('total_daily_screen_seconds') ??
          0;
      final savedRest = prefs.getInt('rhythm_phone_rest_seconds') ?? 0;

      if (savedActive > totalActive) {
        totalActive = savedActive;
      }
      if (savedRest > totalRest) {
        totalRest = savedRest;
      }

      // Check reminders count from SharedPreferences as well
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final savedDate =
          prefs.getString('gentle_reminders_date') ??
          prefs.getString('flutter.gentle_reminders_date');
      if (savedDate == todayStr) {
        final prefsReminders =
            prefs.getInt('gentle_reminders_count') ??
            prefs.getInt('flutter.gentle_reminders_count') ??
            0;
        reminders = max(dbReminders, prefsReminders);
      }

      targetSec = prefs.getInt('rhythm_cycle_target_seconds') ?? 1200;
      if (targetSec < 60) {
        targetSec = 1200;
        prefs.setInt('rhythm_cycle_target_seconds', 1200);
      }
      restSec =
          prefs.getInt('rhythm_required_rest_seconds') ??
          prefs.getInt('eye_rest_duration_seconds') ??
          120;
      if (restSec < 20) {
        restSec = 20;
        prefs.setInt('rhythm_required_rest_seconds', 20);
        prefs.setInt('eye_rest_duration_seconds', 20);
      }

      final nowMs = now.millisecondsSinceEpoch;
      final lastMs = prefs.getInt('rhythm_last_active_timestamp_ms') ?? nowMs;
      final elapsedSec = max(0, (nowMs - lastMs) ~/ 1000);

      final lastUptimeMs = prefs.getInt('rhythm_last_uptime_ms') ??
          prefs.getInt('flutter.rhythm_last_uptime_ms') ??
          0;
      final lastElapsedMs = prefs.getInt('rhythm_last_elapsed_ms') ??
          prefs.getInt('flutter.rhythm_last_elapsed_ms') ??
          0;

      final clocks = await SystemScreenTimeService.getSystemClocks();
      final nowUptimeMs = clocks?['uptimeMs'] ?? 0;
      final nowElapsedMs = clocks?['elapsedRealtimeMs'] ?? 0;

      int awakeSec = 0;
      int deepSleepSec = 0;
      bool hasClocks = false;

      if (lastUptimeMs > 0 &&
          lastElapsedMs > 0 &&
          nowUptimeMs >= lastUptimeMs &&
          nowElapsedMs >= lastElapsedMs) {
        awakeSec = max(0, (nowUptimeMs - lastUptimeMs) ~/ 1000);
        final realSpanSec = max(0, (nowElapsedMs - lastElapsedMs) ~/ 1000);
        deepSleepSec = max(0, realSpanSec - awakeSec);
        hasClocks = true;
      }

      // Check if screen was turned off while killed/inactive for >= restSec
      final screenOffMs =
          prefs.getInt('rhythm_screen_off_timestamp_ms') ??
          prefs.getInt('screen_turned_off_ms') ??
          prefs.getInt('flutter.screen_turned_off_ms') ??
          0;
      final screenOnMs =
          prefs.getInt('rhythm_screen_on_timestamp_ms') ??
          prefs.getInt('screen_turned_on_ms') ??
          prefs.getInt('flutter.screen_turned_on_ms') ??
          0;
      final isInteractive =
          prefs.getBool('is_screen_interactive') ??
          prefs.getBool('flutter.is_screen_interactive') ??
          true;

      bool isRestTaken = false;
      if (hasClocks) {
        // Hardware kernel clocks are ground truth: did the device deep sleep for >= restSec?
        if (deepSleepSec >= restSec) {
          isRestTaken = true;
        }
      } else {
        // Fallback when hardware clocks are not available:
        if (screenOffMs > 0) {
          if (!isInteractive || screenOffMs >= screenOnMs) {
            // Screen turned off and stayed off
            isRestTaken = (nowMs - screenOffMs) >= (restSec * 1000);
          } else {
            // Screen turned off, then turned on
            // Meaningful rest is ONLY true if the screen was off for >= restSec
            isRestTaken = (screenOnMs - screenOffMs) >= (restSec * 1000);
          }
        } else if (elapsedSec >= restSec && !isInteractive) {
          isRestTaken = true;
        }
      }

      if (isRestTaken) {
        calculatedSession = 0;
      } else {
        // Device was active while killed: add the awake time!
        final addedActive = hasClocks ? awakeSec : (isInteractive ? elapsedSec : 0);
        calculatedSession = savedSession + addedActive;
        totalActive += addedActive;
      }

      if (targetSec > 0) {
        calculatedSession = calculatedSession % targetSec;
      }

      // Update clocks and session to now
      if (nowUptimeMs > 0 && nowElapsedMs > 0) {
        prefs.setInt('rhythm_last_uptime_ms', nowUptimeMs);
        prefs.setInt('flutter.rhythm_last_uptime_ms', nowUptimeMs);
        prefs.setInt('rhythm_last_elapsed_ms', nowElapsedMs);
        prefs.setInt('flutter.rhythm_last_elapsed_ms', nowElapsedMs);
        prefs.setInt('rhythm_current_session_seconds', calculatedSession);
        prefs.setInt('flutter.rhythm_current_session_seconds', calculatedSession);
        prefs.setInt('rhythm_continuous_session_seconds', calculatedSession);
        prefs.setInt('flutter.rhythm_continuous_session_seconds', calculatedSession);
        prefs.setInt('continuous_screen_seconds', calculatedSession);
        prefs.setInt('flutter.continuous_screen_seconds', calculatedSession);
      }
    } catch (_) {
      calculatedSession = savedSession;
    }

    // Initialize initial block if empty
    List<ScreenActivityBlock> initialBlocks = List.from(blocks);
    if (initialBlocks.isEmpty) {
      final initialBlock = ScreenActivityBlock(
        startTime: now,
        endTime: now,
        type: ActivityType.activeScreen,
      );
      try {
        _activeBlockId = _db.insertActivityBlock(initialBlock);
      } catch (_) {}
      initialBlocks.add(initialBlock);
    } else {
      _activeBlockId = initialBlocks.last.id;
    }

    state = _calculateStats(
      state.copyWith(
        blocks: initialBlocks,
        activeScreenSeconds: totalActive,
        phoneRestSeconds: totalRest,
        remindersGiven: reminders,
        currentSessionSeconds: calculatedSession,
        cycleTargetSeconds: targetSec,
        requiredRestSeconds: restSec,
        isScreenOn: true,
      ),
    );

    // Schedule native exact alarm for the remaining seconds in current cycle
    final cycleLap = targetSec > 0
        ? (targetSec - (calculatedSession % targetSec))
        : targetSec;
    final remaining = cycleLap > 5 ? cycleLap : targetSec;
    SystemScreenTimeService.scheduleExactReminder(seconds: remaining);

    // Sync real kernel-level screen & rest intervals
    syncWithSystemUsage();
  }

  /// Syncs real Screen ON and Phone Rest blocks recorded by Android OS
  Future<void> syncWithSystemUsage() async {
    try {
      final now = DateTime.now();
      final hasPerm = await SystemScreenTimeService.hasUsagePermission();

      int continuousSession = state.currentSessionSeconds;

      if (hasPerm) {
        final result = await SystemScreenTimeService.getScreenAndRestBlocks(
          date: now,
          requiredRestSeconds: state.requiredRestSeconds,
        );
        if (result.blocks.isNotEmpty) {
          _db.replaceBlocksForDate(now, result.blocks);

          if (result.currentContinuousActiveSeconds > 0) {
            // Clean cycle reset: current lap in the cycle
            final target = state.cycleTargetSeconds > 0
                ? state.cycleTargetSeconds
                : 1200;
            continuousSession =
                result.currentContinuousActiveSeconds % target;
          } else if (!state.isScreenOn) {
            continuousSession = 0;
          }

          // Check reminders from native alarm receiver
          final prefs = await SharedPreferences.getInstance();
          final todayStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final savedDate =
              prefs.getString('flutter.gentle_reminders_date') ??
              prefs.getString('gentle_reminders_date');
          int reminders = state.remindersGiven;
          if (savedDate == todayStr) {
            final count =
                prefs.getInt('flutter.gentle_reminders_count') ??
                prefs.getInt('gentle_reminders_count') ??
                0;
            reminders = count > reminders ? count : reminders;
          }

          final lastRemMs =
              prefs.getInt('flutter.last_reminder_timestamp_ms') ??
              prefs.getInt('last_reminder_timestamp_ms');
          if (lastRemMs != null && lastRemMs > 0) {
            try {
              _db.insertGentleReminder(
                DateTime.fromMillisecondsSinceEpoch(lastRemMs),
              );
            } catch (_) {}
          }

          state = _calculateStats(
            state.copyWith(
              blocks: result.blocks,
              appUsages: result.appUsages,
              activeScreenSeconds: result.activeScreenSeconds,
              phoneRestSeconds: result.phoneRestSeconds,
              currentSessionSeconds: continuousSession,
              remindersGiven: reminders,
            ),
          );
        }
      } else {
        // Fallback when Usage Access is not enabled:
        // Use hardware kernel clocks ground truth to accurately update rest and session
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();

        final nowMs = now.millisecondsSinceEpoch;
        final restSec = state.requiredRestSeconds > 0
            ? state.requiredRestSeconds
            : 120;
        final isInteractive =
            prefs.getBool('is_screen_interactive') ??
            prefs.getBool('flutter.is_screen_interactive') ??
            state.isScreenOn;

        final clocks = await SystemScreenTimeService.getSystemClocks();
        final nowUptimeMs = clocks?['uptimeMs'] ?? 0;
        final nowElapsedMs = clocks?['elapsedRealtimeMs'] ?? 0;
        final lastUptimeMs = prefs.getInt('rhythm_last_uptime_ms') ??
            prefs.getInt('flutter.rhythm_last_uptime_ms') ??
            0;
        final lastElapsedMs = prefs.getInt('rhythm_last_elapsed_ms') ??
            prefs.getInt('flutter.rhythm_last_elapsed_ms') ??
            0;

        int session = state.currentSessionSeconds;
        int active = state.activeScreenSeconds;

        if (lastUptimeMs > 0 &&
            lastElapsedMs > 0 &&
            nowUptimeMs >= lastUptimeMs &&
            nowElapsedMs >= lastElapsedMs) {
          final awakeSec = max(0, (nowUptimeMs - lastUptimeMs) ~/ 1000);
          final realSpanSec = max(0, (nowElapsedMs - lastElapsedMs) ~/ 1000);
          final deepSleepSec = max(0, realSpanSec - awakeSec);

          if (deepSleepSec >= restSec) {
            session = 0;
          } else if (awakeSec > 0) {
            final target = state.cycleTargetSeconds > 0
                ? state.cycleTargetSeconds
                : 1200;
            session = (session + awakeSec) % target;
            active += awakeSec;
          }

          // Update clocks to now
          prefs.setInt('rhythm_last_uptime_ms', nowUptimeMs);
          prefs.setInt('flutter.rhythm_last_uptime_ms', nowUptimeMs);
          prefs.setInt('rhythm_last_elapsed_ms', nowElapsedMs);
          prefs.setInt('flutter.rhythm_last_elapsed_ms', nowElapsedMs);
          prefs.setInt('rhythm_current_session_seconds', session);
          prefs.setInt('flutter.rhythm_current_session_seconds', session);
          prefs.setInt('rhythm_continuous_session_seconds', session);
          prefs.setInt('flutter.rhythm_continuous_session_seconds', session);
          prefs.setInt('continuous_screen_seconds', session);
          prefs.setInt('flutter.continuous_screen_seconds', session);
        } else {
          final screenOffMs =
              prefs.getInt('rhythm_screen_off_timestamp_ms') ??
              prefs.getInt('screen_turned_off_ms') ??
              prefs.getInt('flutter.screen_turned_off_ms');
          if (!isInteractive && screenOffMs != null) {
            final offSec = (nowMs - screenOffMs) ~/ 1000;
            if (offSec >= restSec) {
              session = 0;
            }
          }
        }

        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final savedDate =
            prefs.getString('gentle_reminders_date') ??
            prefs.getString('flutter.gentle_reminders_date');
        int reminders = state.remindersGiven;
        if (savedDate == todayStr) {
          final count =
              prefs.getInt('gentle_reminders_count') ??
              prefs.getInt('flutter.gentle_reminders_count') ??
              0;
          reminders = count > reminders ? count : reminders;
        }

        final lastRemMs =
            prefs.getInt('last_reminder_timestamp_ms') ??
            prefs.getInt('flutter.last_reminder_timestamp_ms');
        if (lastRemMs != null && lastRemMs > 0) {
          try {
            _db.insertGentleReminder(
              DateTime.fromMillisecondsSinceEpoch(lastRemMs),
            );
          } catch (_) {}
        }

        final effectiveActive = max(active, session);
        continuousSession = session;

        state = _calculateStats(
          state.copyWith(
            currentSessionSeconds: session,
            activeScreenSeconds: effectiveActive,
            isScreenOn: isInteractive,
            remindersGiven: reminders,
          ),
        );
      }

      // Schedule native exact alarm for remaining seconds in current lap
      final target = state.cycleTargetSeconds;
      final cycleLap = target > 0
          ? (target - (continuousSession % target))
          : target;
      final remaining = cycleLap > 5 ? cycleLap : target;
      SystemScreenTimeService.scheduleExactReminder(seconds: remaining);
    } catch (_) {}
  }

  /// 1-second system tick
  void onTick({required bool isScreenInteractive}) {
    _tickCount++;

    if (state.isScreenOn != isScreenInteractive) {
      onScreenStateChanged(isScreenInteractive);
      return;
    }

    if (isScreenInteractive) {
      final wasActive = state.isGentleReminderActive;
      final prevReminders = state.remindersGiven;

      state = _useCase.onScreenTick(state);

      // Check if a gentle reminder was just triggered
      if (!wasActive && state.isGentleReminderActive) {
        _onGentleReminderTriggered();
      } else if (state.remindersGiven > prevReminders) {
        _onGentleReminderTriggered();
      }

      // Periodically persist active block end time (every 5 seconds)
      if (_tickCount % 5 == 0) {
        _persistCurrentBlock();
      }

      // Periodically refresh app usage from OS every 20 seconds while in foreground
      if (_tickCount % 20 == 0) {
        syncWithSystemUsage();
      }
    } else {
      state = _useCase.onScreenOffTick(state);

      // Periodically persist phone rest block end time (every 10 seconds)
      if (_tickCount % 10 == 0) {
        _persistCurrentBlock();
      }
    }
  }

  /// Invoked when physical display turns ON or OFF
  void onScreenStateChanged(bool isInteractive) {
    final now = DateTime.now();

    if (!isInteractive && state.isScreenOn) {
      // Screen Turned OFF
      _persistCurrentBlock();
      try {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt(
            'rhythm_screen_off_timestamp_ms',
            now.millisecondsSinceEpoch,
          );
        });
      } catch (_) {}

      state = _useCase.onScreenTurnedOff(state, timestamp: now);

      // Create new Phone Rest block in SQLite
      try {
        final newBlock = ScreenActivityBlock(
          startTime: now,
          endTime: now,
          type: ActivityType.phoneRest,
        );
        _activeBlockId = _db.insertActivityBlock(newBlock);
      } catch (_) {}
    } else if (isInteractive && !state.isScreenOn) {
      // Screen Turned ON
      _persistCurrentBlock();
      try {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt(
            'rhythm_screen_on_timestamp_ms',
            now.millisecondsSinceEpoch,
          );
        });
      } catch (_) {}

      state = _useCase.onScreenTurnedOn(state, timestamp: now);

      if (state.currentSessionSeconds == 0) {
        try {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setInt('rhythm_current_session_seconds', 0);
            prefs.setInt('rhythm_continuous_session_seconds', 0);
            prefs.setInt('continuous_screen_seconds', 0);
          });
        } catch (_) {}
      }

      // Create new Active Screen block in SQLite
      try {
        final newBlock = ScreenActivityBlock(
          startTime: now,
          endTime: now,
          type: ActivityType.activeScreen,
        );
        _activeBlockId = _db.insertActivityBlock(newBlock);
      } catch (_) {}
    }
  }

  /// Called when a continuous screen threshold is met (20m, 40m, 60m...)
  void _onGentleReminderTriggered() {
    final now = DateTime.now();
    _db.insertGentleReminder(now);
    // Note: state.remindersGiven was already incremented in onScreenTick().
    // We do NOT increment it again here to prevent flickering/double-increment.

    final continuousMins = max(
      1,
      (state.cycleTargetSeconds > 0 ? state.cycleTargetSeconds : 1200) ~/ 60,
    );
    final restSec = state.requiredRestSeconds > 0
        ? state.requiredRestSeconds
        : 120;
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('last_reminder_timestamp_ms', now.millisecondsSinceEpoch);
        prefs.setInt(
          'flutter.last_reminder_timestamp_ms',
          now.millisecondsSinceEpoch,
        );
        prefs.setString('gentle_reminders_date', todayStr);
        prefs.setString('flutter.gentle_reminders_date', todayStr);
        prefs.setInt('gentle_reminders_count', state.remindersGiven);
        prefs.setInt('flutter.gentle_reminders_count', state.remindersGiven);
        prefs.setInt(
          'rhythm_current_session_seconds',
          state.currentSessionSeconds,
        );
        prefs.setInt(
          'rhythm_continuous_session_seconds',
          state.currentSessionSeconds,
        );
        prefs.setInt('continuous_screen_seconds', state.currentSessionSeconds);
        prefs.setInt('rhythm_active_screen_seconds', state.activeScreenSeconds);
      });
    } catch (_) {}

    // Show native gentle notification with dynamic continuous time and rest duration (auto-dismisses after 25s)
    NotificationService.showGentleEyeReminder(
      continuousMinutes: continuousMins,
      restSeconds: restSec,
      timeoutSeconds: 25,
    );

    // Auto-dismiss the in-app gentle toast/banner after 25 seconds
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 25), () {
      if (mounted) {
        dismissGentleReminder();
      }
    });
  }

  /// Dismisses the gentle reminder without any penalty or guilt
  void dismissGentleReminder() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    state = _useCase.dismissGentleReminder(state);
  }

  /// Configures the continuous screen target (presets or custom minutes/seconds)
  void setCycleTargetSeconds(int seconds) {
    final effectiveSec = seconds >= 60 ? seconds : 1200;
    state = _calculateStats(state.copyWith(cycleTargetSeconds: effectiveSec));
    final cycleLap = effectiveSec > 0
        ? (effectiveSec - (state.currentSessionSeconds % effectiveSec))
        : effectiveSec;
    final remaining = cycleLap > 5 ? cycleLap : effectiveSec;
    SystemScreenTimeService.scheduleExactReminder(seconds: remaining);
    _db.setSetting('eye_interval_seconds', effectiveSec.toString());
    _db.setSetting('eye_interval_minutes', (effectiveSec ~/ 60).toString());
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('rhythm_cycle_target_seconds', effectiveSec);
        prefs.setInt('eye_interval_seconds', effectiveSec);
      });
      FlutterBackgroundService().invoke('update_eye_settings', {
        'intervalSeconds': effectiveSec,
        'isSeconds': false,
        'reset': true,
      });
    } catch (_) {}
  }

  /// Configures the required rest duration needed to reset continuous session to 0 (minimum 20s)
  void setRequiredRestSeconds(int seconds) {
    final effectiveSec = seconds >= 20 ? seconds : 20;
    state = state.copyWith(requiredRestSeconds: effectiveSec);
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('rhythm_required_rest_seconds', effectiveSec);
        prefs.setInt('eye_rest_duration_seconds', effectiveSec);
      });
      FlutterBackgroundService().invoke('update_eye_settings', {
        'restSeconds': effectiveSec,
      });
    } catch (_) {}
  }

  /// Resets the current continuous cycle to 0 manually
  void resetCycle() {
    state = state.copyWith(currentSessionSeconds: 0);
    SystemScreenTimeService.scheduleExactReminder(
      seconds: state.cycleTargetSeconds,
    );
  }

  DailyRhythmEntity _calculateStats(DailyRhythmEntity current) {
    int maxSec = 0;
    String topApp = 'None';

    final longestStrain = StrainSessionDetail.calculateLongestStrain(
      current.blocks,
      minRestThresholdSeconds: current.requiredRestSeconds,
    );
    if (longestStrain != null) {
      maxSec = longestStrain.durationSeconds;
      topApp = longestStrain.topAppName;
    }

    int promptRests = 0;
    int ignoredReminders = 0;

    for (final b in current.blocks) {
      if (b.isActiveScreen) {
        // Timer compliance: prompt rest within 5-15s of alert vs ignored marathon
        if (b.durationSeconds >= (current.cycleTargetSeconds * 1.35)) {
          ignoredReminders++;
        } else if (b.durationSeconds >= (current.cycleTargetSeconds * 0.90)) {
          promptRests++;
        }
      }
    }

    final total = promptRests + ignoredReminders;
    final rate = total > 0 ? (promptRests / total).clamp(0.0, 1.0) : 1.0;

    final target = current.cycleTargetSeconds > 0
        ? current.cycleTargetSeconds
        : 1200;
    final cleanSession = current.currentSessionSeconds % target;

    return current.copyWith(
      activeScreenSeconds: current.activeScreenSeconds,
      currentSessionSeconds: cleanSession,
      longestContinuousSeconds: maxSec,
      longestContinuousApp: topApp,
      timerRespectRate: rate,
      promptRestsCount: promptRests,
      ignoredRemindersCount: ignoredReminders,
    );
  }

  void _persistCurrentBlock() {
    if (_activeBlockId != null) {
      try {
        _db.updateActivityBlock(_activeBlockId!, DateTime.now());
      } catch (_) {}
    }
    try {
      SystemScreenTimeService.getSystemClocks().then((clocks) {
        SharedPreferences.getInstance().then((prefs) {
          final now = DateTime.now();
          prefs.setInt(
            'rhythm_current_session_seconds',
            state.currentSessionSeconds,
          );
          prefs.setInt(
            'flutter.rhythm_current_session_seconds',
            state.currentSessionSeconds,
          );
          prefs.setInt(
            'rhythm_continuous_session_seconds',
            state.currentSessionSeconds,
          );
          prefs.setInt(
            'flutter.rhythm_continuous_session_seconds',
            state.currentSessionSeconds,
          );
          prefs.setInt('continuous_screen_seconds', state.currentSessionSeconds);
          prefs.setInt(
            'flutter.continuous_screen_seconds',
            state.currentSessionSeconds,
          );
          prefs.setInt(
            'rhythm_last_active_timestamp_ms',
            now.millisecondsSinceEpoch,
          );
          prefs.setInt(
            'flutter.rhythm_last_active_timestamp_ms',
            now.millisecondsSinceEpoch,
          );
          prefs.setInt('rhythm_active_screen_seconds', state.activeScreenSeconds);
          prefs.setInt('flutter.rhythm_active_screen_seconds', state.activeScreenSeconds);
          prefs.setInt('rhythm_phone_rest_seconds', state.phoneRestSeconds);
          prefs.setInt('flutter.rhythm_phone_rest_seconds', state.phoneRestSeconds);
          if (clocks != null) {
            prefs.setInt('rhythm_last_uptime_ms', clocks['uptimeMs']!);
            prefs.setInt('flutter.rhythm_last_uptime_ms', clocks['uptimeMs']!);
            prefs.setInt('rhythm_last_elapsed_ms', clocks['elapsedRealtimeMs']!);
            prefs.setInt('flutter.rhythm_last_elapsed_ms', clocks['elapsedRealtimeMs']!);
          }
        });
      });
    } catch (_) {}
  }

  /// Persists current session and hardware clocks immediately when app goes to background or exits
  void persistStateBeforeExit() {
    _persistCurrentBlock();
    final target = state.cycleTargetSeconds;
    final cycleLap = target > 0
        ? (target - (state.currentSessionSeconds % target))
        : target;
    final remaining = cycleLap > 5 ? cycleLap : target;
    SystemScreenTimeService.scheduleExactReminder(seconds: remaining);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _persistCurrentBlock();
    super.dispose();
  }
}

/// Global provider for Daily Rhythm and Pure Device Activity tracking
final dailyRhythmProvider =
    StateNotifierProvider<DailyRhythmNotifier, DailyRhythmEntity>((ref) {
      final db = ref.watch(databaseProvider);
      return DailyRhythmNotifier(db);
    });
