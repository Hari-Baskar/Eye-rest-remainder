import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/providers.dart';
import '../../../eye_rest/domain/entities/daily_rhythm_entity.dart';

export 'continuous_target_modal_sheet.dart';
export 'required_rest_modal_sheet.dart';

/// EditDurationsModalSheet
///
/// Sleek modal sheet to edit Continuous Screen Target & Required Rest Duration
/// with min/sec precision.
class EditDurationsModalSheet extends ConsumerStatefulWidget {
  final DailyRhythmEntity rhythm;

  const EditDurationsModalSheet({super.key, required this.rhythm});

  static void show(BuildContext context, DailyRhythmEntity rhythm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditDurationsModalSheet(rhythm: rhythm),
    );
  }

  @override
  ConsumerState<EditDurationsModalSheet> createState() =>
      _EditDurationsModalSheetState();
}

class _EditDurationsModalSheetState
    extends ConsumerState<EditDurationsModalSheet> {
  late TextEditingController _continuousCtrl;
  late TextEditingController _restCtrl;
  bool _continuousIsSeconds = false;
  bool _restIsSeconds = false;

  @override
  void initState() {
    super.initState();
    final initContinuousSec = widget.rhythm.cycleTargetSeconds;
    _continuousIsSeconds = initContinuousSec < 60;
    _continuousCtrl = TextEditingController(
      text: _continuousIsSeconds
          ? initContinuousSec.toString()
          : (initContinuousSec ~/ 60).toString(),
    );

    final initRestSec = widget.rhythm.requiredRestSeconds;
    _restIsSeconds = initRestSec < 60;
    _restCtrl = TextEditingController(
      text: _restIsSeconds
          ? initRestSec.toString()
          : (initRestSec ~/ 60).toString(),
    );
  }

  @override
  void dispose() {
    _continuousCtrl.dispose();
    _restCtrl.dispose();
    super.dispose();
  }

  int get _continuousSec {
    final val = int.tryParse(_continuousCtrl.text.trim()) ?? 20;
    return _continuousIsSeconds ? val : val * 60;
  }

  int get _restSec {
    final val = int.tryParse(_restCtrl.text.trim()) ?? 2;
    return _restIsSeconds ? val : val * 60;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final secondaryColor = AppColors.getRhythmBlue(isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 14),

            // Sheet Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Timer Settings',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Field 1: Continuous Screen Target
            Text(
              'Continuous Screen Target',
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _continuousCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textCharcoal,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: '20',
                      ),
                    ),
                  ),
                  _buildUnitSelector(
                    isSeconds: _continuousIsSeconds,
                    activeColor: primaryColor,
                    isDark: isDark,
                    onToggle: (sec) =>
                        setState(() => _continuousIsSeconds = sec),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Field 2: Required Rest Duration
            Text(
              'Required Rest Duration',
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.spa_outlined, size: 18, color: secondaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _restCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textCharcoal,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: '2',
                      ),
                    ),
                  ),
                  _buildUnitSelector(
                    isSeconds: _restIsSeconds,
                    activeColor: secondaryColor,
                    isDark: isDark,
                    onToggle: (sec) => setState(() => _restIsSeconds = sec),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  final continuousSec =
                      _continuousSec >= 60 ? _continuousSec : 1200;
                  final restSec = _restSec > 0 ? _restSec : 120;
                  ref
                      .read(dailyRhythmProvider.notifier)
                      .setCycleTargetSeconds(continuousSec);
                  ref
                      .read(dailyRhythmProvider.notifier)
                      .setRequiredRestSeconds(restSec);
                  ref
                      .read(eyeRestProvider.notifier)
                      .setIntervalSeconds(continuousSec);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildUnitSelector({
    required bool isSeconds,
    required Color activeColor,
    required bool isDark,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onToggle(false),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: !isSeconds ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'min',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !isSeconds
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onToggle(true),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSeconds ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'sec',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSeconds
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

