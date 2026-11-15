import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/providers.dart';
import '../../../eye_rest/domain/entities/daily_rhythm_entity.dart';

/// ContinuousTargetModalSheet
///
/// Clean, minimal Digital Wellbeing-style time picker modal for setting
/// the continuous screen time goal before an eye break alert triggers.
class ContinuousTargetModalSheet extends ConsumerStatefulWidget {
  final DailyRhythmEntity rhythm;

  const ContinuousTargetModalSheet({super.key, required this.rhythm});

  static Future<void> show(
    BuildContext context,
    DailyRhythmEntity rhythm,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContinuousTargetModalSheet(rhythm: rhythm),
    );
  }

  @override
  ConsumerState<ContinuousTargetModalSheet> createState() =>
      _ContinuousTargetModalSheetState();
}

class _ContinuousTargetModalSheetState
    extends ConsumerState<ContinuousTargetModalSheet> {
  late int _selectedHours;
  late int _selectedMinutes;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  static const List<int> _hourOptions = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  static final List<int> _minuteOptions = List.generate(60, (i) => i);

  @override
  void initState() {
    super.initState();
    final totalSec = widget.rhythm.cycleTargetSeconds;
    final totalMin = (totalSec / 60).round();
    _selectedHours = (totalMin ~/ 60).clamp(0, 12);
    _selectedMinutes = (totalMin % 60).clamp(0, 59);

    final hourIndex = _hourOptions.indexOf(_selectedHours);
    final minuteIndex = _minuteOptions.indexOf(_selectedMinutes);

    _hourController = FixedExtentScrollController(
      initialItem: hourIndex >= 0 ? hourIndex : 0,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: minuteIndex >= 0 ? minuteIndex : 20,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  int get _calculatedSeconds {
    final sec = (_selectedHours * 3600) + (_selectedMinutes * 60);
    return sec > 0 ? sec : 1200; // minimum 1 min, defaults to 20m if 0
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Center drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Text(
                'Continuous Screen Target',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Digital Wellbeing Time Roller Picker
              SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Highlight capsule for selected row
                    Container(
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                    // Two Wheel Columns (Hours & Minutes)
                    Row(
                      children: [
                        // Hours Column
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: _hourController,
                            itemExtent: 46,
                            perspective: 0.003,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedHours = _hourOptions[index];
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _hourOptions.length,
                              builder: (context, index) {
                                final h = _hourOptions[index];
                                final isSelected = h == _selectedHours;
                                return Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$h',
                                        style: TextStyle(
                                          fontSize: isSelected ? 26 : 17,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          fontFamily: 'monospace',
                                          color: isSelected
                                              ? (isDark
                                                  ? Colors.white
                                                  : AppColors.textPrimary)
                                              : (isDark
                                                  ? AppColors.darkTextTertiary
                                                  : AppColors.textTertiary),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'hours',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? (isDark
                                                  ? Colors.white70
                                                  : AppColors.textPrimary)
                                              : (isDark
                                                  ? AppColors.darkTextTertiary
                                                  : AppColors.textTertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Minutes Column
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: _minuteController,
                            itemExtent: 46,
                            perspective: 0.003,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedMinutes = _minuteOptions[index];
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _minuteOptions.length,
                              builder: (context, index) {
                                final m = _minuteOptions[index];
                                final isSelected = m == _selectedMinutes;
                                return Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        m.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: isSelected ? 26 : 17,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          fontFamily: 'monospace',
                                          color: isSelected
                                              ? (isDark
                                                  ? Colors.white
                                                  : AppColors.textPrimary)
                                              : (isDark
                                                  ? AppColors.darkTextTertiary
                                                  : AppColors.textTertiary),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'mins',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: isSelected
                                              ? (isDark
                                                  ? Colors.white70
                                                  : AppColors.textPrimary)
                                              : (isDark
                                                  ? AppColors.darkTextTertiary
                                                  : AppColors.textTertiary),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons (Digital Wellbeing: Cancel & Set)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final continuousSec = _calculatedSeconds;
                      ref
                          .read(dailyRhythmProvider.notifier)
                          .setCycleTargetSeconds(continuousSec);
                      ref
                          .read(eyeRestProvider.notifier)
                          .setIntervalSeconds(continuousSec);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Set',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
