import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/providers.dart';
import '../../../eye_rest/domain/entities/daily_rhythm_entity.dart';

/// RequiredRestModalSheet
///
/// Clean, minimal Digital Wellbeing-style time picker modal for setting
/// the required rest duration needed to reset continuous screen sessions to 0.
class RequiredRestModalSheet extends ConsumerStatefulWidget {
  final DailyRhythmEntity rhythm;

  const RequiredRestModalSheet({super.key, required this.rhythm});

  static Future<void> show(
    BuildContext context,
    DailyRhythmEntity rhythm,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RequiredRestModalSheet(rhythm: rhythm),
    );
  }

  @override
  ConsumerState<RequiredRestModalSheet> createState() =>
      _RequiredRestModalSheetState();
}

class _RequiredRestModalSheetState
    extends ConsumerState<RequiredRestModalSheet> {
  late int _selectedMinutes;
  late int _selectedSeconds;

  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _secondController;

  static final List<int> _minuteOptions = List.generate(31, (i) => i);
  static final List<int> _secondOptions = List.generate(60, (i) => i);

  @override
  void initState() {
    super.initState();
    final totalSec = widget.rhythm.requiredRestSeconds;
    _selectedMinutes = (totalSec ~/ 60).clamp(0, 30);
    _selectedSeconds = (totalSec % 60).clamp(0, 59);

    final minuteIndex = _minuteOptions.indexOf(_selectedMinutes);
    final secondIndex = _secondOptions.indexOf(_selectedSeconds);

    _minuteController = FixedExtentScrollController(
      initialItem: minuteIndex >= 0 ? minuteIndex : 2,
    );
    _secondController = FixedExtentScrollController(
      initialItem: secondIndex >= 0 ? secondIndex : 0,
    );
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  int get _calculatedSeconds {
    final sec = (_selectedMinutes * 60) + _selectedSeconds;
    return sec >= 20
        ? sec
        : 20; // Strictly enforce minimum 20s rest (20-20-20 rule)
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
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.20,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Text(
                'Required Rest Duration',
                style: AppTextStyles.heading.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Digital Wellbeing Time Roller Picker (Minutes & Seconds)
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

                    // Two Wheel Columns (Minutes & Seconds)
                    Row(
                      children: [
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
                                        '$m',
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

                        // Seconds Column
                        Expanded(
                          child: ListWheelScrollView.useDelegate(
                            controller: _secondController,
                            itemExtent: 46,
                            perspective: 0.003,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedSeconds = _secondOptions[index];
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: _secondOptions.length,
                              builder: (context, index) {
                                final s = _secondOptions[index];
                                final isSelected = s == _selectedSeconds;
                                return Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        s.toString().padLeft(2, '0'),
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
                                        'secs',
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
              if (_selectedMinutes == 0 && _selectedSeconds < 20) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Minimum eye rest is 20s (20-20-20 rule)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
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
                      final restSec = _calculatedSeconds;
                      ref
                          .read(dailyRhythmProvider.notifier)
                          .setRequiredRestSeconds(restSec);
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
