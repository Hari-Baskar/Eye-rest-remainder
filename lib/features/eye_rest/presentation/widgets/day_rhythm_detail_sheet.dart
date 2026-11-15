import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../screens/eye_rest_detail_screen.dart';

/// DayRhythmDetailSheet
///
/// Reuses EyeRestDetailScreen for per-day historical details with timer hidden.
/// Completely avoids duplicating screens while keeping full interactive functionality.
class DayRhythmDetailSheet {
  static Future<void> show({
    required BuildContext context,
    required AppDatabase db,
    required DateTime date,
    required String dateTitle,
    required String dateSubtitle,
    int? screenTimeSeconds,
    int? breaksCount,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EyeRestDetailScreen(initialDate: date),
      ),
    );
  }
}

/// Backwards compatibility alias
typedef DayStoryboardScreen = DayRhythmDetailSheet;
