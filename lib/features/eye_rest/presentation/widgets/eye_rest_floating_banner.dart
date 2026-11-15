import 'package:flutter/widgets.dart';

/// EyeRestFloatingBanner
///
/// Deprecated: Floating overlay pill removed.
class EyeRestFloatingBanner {
  static Future<void> show(
    BuildContext context, {
    bool isDemo = false,
    VoidCallback? onComplete,
  }) async {
    onComplete?.call();
  }
}
