/// OverlayService
///
/// Decommissioned: Floating pill overlay has been retired in favor of
/// clean, professional native Android notifications.
class OverlayService {
  static Future<bool> canDrawOverlays() async => false;
  static Future<void> requestOverlayPermission() async {}
  static Future<bool> isGameActive() async => false;
  static Future<void> showFloatingOverlay() async {}
  static Future<void> hideFloatingOverlay() async {}
}
