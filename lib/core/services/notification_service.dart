import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_strings.dart';
import '../database/app_database.dart';
import '../utils/user_name_helper.dart';

/// NotificationService
///
/// Centralized service for initializing Android notification channels
/// and dispatching high-priority wellness alerts strictly for Eye Break Reminders.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelEyeBreak = 'eye_break_high_priority_v3';
  static const String channelForeground = 'my_foreground';

  /// Initializes local notification settings and registers Eye Break channel
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (_) {}

      // Clean up any old unused channels and persistent notifications
      try {
        await androidPlugin.deleteNotificationChannel(channelId: 'eye_break_channel');
        await androidPlugin.deleteNotificationChannel(channelId: 'posture_alerts');
        await androidPlugin.deleteNotificationChannel(channelId: channelForeground);
        await androidPlugin.deleteNotificationChannel(channelId: 'background_service');
        await androidPlugin.deleteNotificationChannel(channelId: 'gentle_eye_care');
        await _notificationsPlugin.cancel(id: 888);
        await _notificationsPlugin.cancel(id: 102);
        await _notificationsPlugin.cancel(id: 999);
      } catch (_) {}

      // Channel 1: High Priority Eye Break Alerts (Heads-up pop-down over apps)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelEyeBreak,
          'Eye Rest Alerts',
          description: 'High-priority reminders to rest your eyes',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  /// Sends an Eye Break alert as a clean, high-priority native notification
  static Future<void> showEyeBreakAlert(
    int duration, {
    String? userName,
    bool isSeconds = false,
    int restSeconds = 120,
    String breakStyle = 'notification',
    bool isGamingDefense = true,
    bool isMediaPlaying = false,
    bool? isOverlayEnabled,
  }) async {
    try {
      AppDatabase.instance.insertGentleReminder(DateTime.now());
    } catch (_) {}

    final name = userName ?? await UserNameHelper.getBackgroundUserName();
    final timeStr = isSeconds ? '$duration seconds' : '$duration minutes';

    final String restStr;
    if (restSeconds >= 60) {
      final m = restSeconds ~/ 60;
      final s = restSeconds % 60;
      restStr = s == 0 ? '$m-minute' : '$m min $s sec';
    } else {
      restStr = '$restSeconds-second';
    }

    const androidDetails = AndroidNotificationDetails(
      channelEyeBreak,
      'Eye Rest Alerts',
      channelDescription: 'High-priority reminders to rest your eyes',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      ticker: 'Eye Break Time!',
      playSound: true,
      enableVibration: true,
      timeoutAfter: 25000,
      autoCancel: true,
    );

    await _notificationsPlugin.show(
      id: 101,
      title: 'Hey $name, Eye Break Time! 👁️',
      body:
          'Continuous screen time reached $timeStr. Take a $restStr eye rest now!',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Delivers a high-priority heads-up reminder following the Gentle Delivery model:
  /// - Heads-up pop-down banner over active apps with gentle vibration.
  /// - Auto-dismisses automatically after 25 seconds in notification drawer.
  /// - Shares the exact same Notification ID 101 so alerts update in-place without duplicate stacking.
  static Future<void> showGentleEyeReminder({
    int continuousMinutes = 20,
    int restSeconds = 120,
    int timeoutSeconds = 25,
  }) async {
    try {
      AppDatabase.instance.insertGentleReminder(DateTime.now());
    } catch (_) {}

    final String restStr;
    if (restSeconds >= 60) {
      final m = restSeconds ~/ 60;
      final s = restSeconds % 60;
      restStr = s == 0 ? '$m min' : '$m min $s sec';
    } else {
      restStr = '$restSeconds seconds';
    }

    final androidDetails = AndroidNotificationDetails(
      channelEyeBreak,
      'Eye Rest Alerts',
      channelDescription: 'High-priority reminders to rest your eyes',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      ticker: 'Eye Break Reminder',
      timeoutAfter: timeoutSeconds * 1000,
      autoCancel: true,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin.show(
      id: 101,
      title: 'Eye Rest • $continuousMinutes Minutes 👁️',
      body:
          '$continuousMinutes minutes continuous screen time. Rest your eyes for $restStr.',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }
}
