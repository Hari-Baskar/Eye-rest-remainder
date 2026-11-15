import 'package:flutter/services.dart';

/// DeviceScreenTimeDataSource
///
/// Communicates with native Android `UsageStatsManager` via MethodChannel to fetch
/// actual system-wide device screen-on duration for the current day.
class DeviceScreenTimeDataSource {
  static const MethodChannel _platform = MethodChannel('com.reset/call_proximity');

  /// Checks if Android `PACKAGE_USAGE_STATS` access permission is granted
  Future<bool> hasUsageStatsPermission() async {
    try {
      final bool? granted = await _platform.invokeMethod<bool>('hasUsageStatsPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches total daily screen time in seconds directly from the Android phone
  Future<int> getDeviceDailyScreenTimeSeconds() async {
    try {
      final int? seconds = await _platform.invokeMethod<int>('getDeviceDailyScreenTime');
      return seconds ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Opens Android Settings -> Usage Access so user can grant permission
  Future<void> openUsageSettings() async {
    try {
      await _platform.invokeMethod('openUsageSettings');
    } catch (_) {}
  }
}
