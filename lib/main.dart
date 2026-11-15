import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/database/app_database.dart';
import 'core/providers/providers.dart';

import 'features/eye_rest/presentation/screens/eye_rest_detail_screen.dart';
import 'core/services/notification_service.dart';

import 'features/call_detection/domain/entities/call_state_entity.dart';
import 'features/call_detection/data/datasources/call_state_data_source.dart';

import 'features/progress/presentation/screens/history_screen.dart';
import 'features/settings/presentation/widgets/settings_drawer.dart';

import 'services/background_service.dart';

/// Application entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppDatabase.instance.init();
    await initializeService();
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
  runApp(const ProviderScope(child: LifeMintApp()));
}

/// LifeMintApp
///
/// Root MaterialApp configuring themes (Light & Dark) and the primary wellness shell.
class LifeMintApp extends StatefulWidget {
  const LifeMintApp({super.key});

  static void Function()? onGlobalTouch;
  static DateTime? _lastGlobalTouchSentTime;
  static void registerGlobalPointerInteraction() {
    final now = DateTime.now();
    if (_lastGlobalTouchSentTime == null ||
        now.difference(_lastGlobalTouchSentTime!).inMilliseconds > 600) {
      _lastGlobalTouchSentTime = now;
      FlutterBackgroundService().invoke('touch_interaction', {
        'isInteracting': true,
      });
    }
    onGlobalTouch?.call();
  }

  @override
  State<LifeMintApp> createState() => _LifeMintAppState();
}

class _LifeMintAppState extends State<LifeMintApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.cardSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          secondary: AppColors.mintAccent,
          surface: AppColors.darkCardSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Listener(
          onPointerDown: (_) => LifeMintApp.registerGlobalPointerInteraction(),
          onPointerMove: (_) => LifeMintApp.registerGlobalPointerInteraction(),
          behavior: HitTestBehavior.translucent,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: LifeMintShell(
        currentThemeMode: _themeMode,
        onThemeChanged: _setThemeMode,
      ),
    );
  }
}

/// LifeMintShell
///
/// Multi-tab host managing Home, Progress, and Settings tabs with Riverpod state management.
class LifeMintShell extends ConsumerStatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode mode) onThemeChanged;

  const LifeMintShell({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  ConsumerState<LifeMintShell> createState() => _LifeMintShellState();
}

class _LifeMintShellState extends ConsumerState<LifeMintShell>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Global Call State
  CallStateEntity _callState = CallStateEntity.initial();

  // Data Sources
  final CallStateDataSource _callDataSource = CallStateDataSource();

  // Subscriptions & Timers
  StreamSubscription? _serviceScreenTimeSubscription;
  StreamSubscription? _callStateSubscription;
  Timer? _foregroundScreenTimer;
  DateTime? _lastBgTickReceived;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LifeMintApp.onGlobalTouch = _onUserPointerInteraction;
    FlutterBackgroundService().invoke('app_lifecycle', {'state': 'resumed'});
    _initSensorsAndServices();

    // Ensure any legacy 20-second test interval in storage is sanitized to 20 minutes (1200s)
    SharedPreferences.getInstance()
        .then((prefs) {
          final eyeSec = prefs.getInt('eye_interval_seconds');
          if (eyeSec != null && eyeSec < 60) {
            prefs.setInt('eye_interval_seconds', 1200);
            prefs.setInt('eye_interval_minutes', 20);
          }
          final rhythmSec = prefs.getInt('rhythm_cycle_target_seconds');
          if (rhythmSec != null && rhythmSec < 60) {
            prefs.setInt('rhythm_cycle_target_seconds', 1200);
          }
        })
        .catchError((_) {});
    _callDataSource.checkCurrentState().then((state) {
      if (mounted) {
        setState(() => _callState = state);
        if (ref.read(dailyRhythmProvider).isScreenOn != state.isScreenInteractive) {
          ref
              .read(dailyRhythmProvider.notifier)
              .onScreenStateChanged(state.isScreenInteractive);
        }
        FlutterBackgroundService().invoke('call_state_update', {
          'isInCall': state.isInCall,
          'isProximityNear': state.isProximityNear,
          'isScreenInteractive': state.isScreenInteractive,
          'isMediaPlaying': state.isMediaPlaying,
        });
      }
    });
    _startForegroundTimers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final eyeRest = ref.read(eyeRestProvider);
      FlutterBackgroundService().invoke('update_eye_settings', {
        'isEnabled': eyeRest.isEnabled,
        'intervalSeconds': eyeRest.intervalSeconds,
        'interval': eyeRest.intervalMinutes,
        'isOverlayEnabled': eyeRest.isOverlayEnabled,
        'isGamingDefense': eyeRest.isGamingDefenseEnabled,
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LifeMintApp.onGlobalTouch = null;
    _serviceScreenTimeSubscription?.cancel();
    _callStateSubscription?.cancel();
    _foregroundScreenTimer?.cancel();
    _callDataSource.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FlutterBackgroundService().invoke('app_lifecycle', {'state': state.name});

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ref.read(dailyRhythmProvider.notifier).persistStateBeforeExit();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(eyeRestProvider.notifier).syncFromStorage();
      ref.read(dailyRhythmProvider.notifier).syncWithSystemUsage();
      _callDataSource.checkCurrentState().then((s) {
        if (mounted) {
          setState(() => _callState = s);
          if (ref.read(dailyRhythmProvider).isScreenOn != s.isScreenInteractive) {
            ref
                .read(dailyRhythmProvider.notifier)
                .onScreenStateChanged(s.isScreenInteractive);
          }
          FlutterBackgroundService().invoke('call_state_update', {
            'isInCall': s.isInCall,
            'isProximityNear': s.isProximityNear,
            'isScreenInteractive': s.isScreenInteractive,
            'isMediaPlaying': s.isMediaPlaying,
          });
        }
      });
    }
  }

  /// Subscribes to background service broadcasts
  void _initSensorsAndServices() {
    // Background Service Screen Time broadcast
    final service = FlutterBackgroundService();
    _serviceScreenTimeSubscription = service.on('screen_time_tick').listen((
      event,
    ) {
      if (event != null && mounted) {
        _lastBgTickReceived = DateTime.now();
        final sec = (event['seconds'] as num?)?.toInt();
        final totalDaily = (event['totalDailySeconds'] as num?)?.toInt();
        final breaks = (event['breaksCount'] as num?)?.toInt();
        final isMedia = event['isMediaPlaying'] as bool?;
        if (sec != null) {
          ref
              .read(eyeRestProvider.notifier)
              .setScreenMetrics(
                currentSeconds: sec,
                totalDailySeconds: totalDaily,
                breaksCount: breaks,
                isMediaPlaying: isMedia,
              );
        }
      }
    });

    service.on('eye_break_auto_completed').listen((event) {
      if (mounted) {
        final breaks = (event?['breaksCount'] as num?)?.toInt();
        ref.read(eyeRestProvider.notifier).recordAutoBreak(breaksCount: breaks);
      }
    });

    // Call, Proximity, Media, and Screen Interactive State stream
    _callStateSubscription = _callDataSource.callStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _callState = state;
        });
        if (ref.read(dailyRhythmProvider).isScreenOn != state.isScreenInteractive) {
          ref
              .read(dailyRhythmProvider.notifier)
              .onScreenStateChanged(state.isScreenInteractive);
        }
        service.invoke('call_state_update', {
          'isInCall': state.isInCall,
          'isProximityNear': state.isProximityNear,
          'isScreenInteractive': state.isScreenInteractive,
          'isMediaPlaying': state.isMediaPlaying,
        });
      }
    });
  }

  /// Registers user touch/scroll events
  void _onUserPointerInteraction() {
    FlutterBackgroundService().invoke('touch_interaction', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Periodic sync and active foreground timers
  void _startForegroundTimers() {
    // 1-second continuous foreground screen timer
    _foregroundScreenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        // Daily Rhythm pure device activity tick
        ref
            .read(dailyRhythmProvider.notifier)
            .onTick(isScreenInteractive: _callState.isScreenInteractive);

        final isBgEmitting =
            _lastBgTickReceived != null &&
            DateTime.now().difference(_lastBgTickReceived!).inSeconds < 2;
        if (!isBgEmitting) {
          final eyeRest = ref.read(eyeRestProvider);
          if (eyeRest.isEnabled && !_callState.shouldMuteTracking) {
            ref.read(eyeRestProvider.notifier).onScreenTick(1);
          }
        }
      }
    });
  }

  void _openAllHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SettingsDrawer(
        currentThemeMode: widget.currentThemeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
      body: EyeRestDetailScreen(
        onOpenSettings: () => _scaffoldKey.currentState?.openDrawer(),
        onOpenAllHistory: _openAllHistory,
        currentThemeMode: widget.currentThemeMode,
        onThemeChanged: widget.onThemeChanged,
      ),
    );
  }
}
