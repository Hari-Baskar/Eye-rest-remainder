import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// SelectHabitsScreen
///
/// Screen 3 in the LifeMint onboarding flow.
/// Allows the user to select which habit pillars they want to actively track.
class SelectHabitsScreen extends StatefulWidget {
  final bool initialWater;
  final bool initialSunlight;
  final bool initialEyeRest;
  final bool initialSteps;
  final Function(bool water, bool sunlight, bool eyeRest, bool steps) onContinue;

  const SelectHabitsScreen({
    super.key,
    this.initialWater = true,
    this.initialSunlight = true,
    this.initialEyeRest = true,
    this.initialSteps = true,
    required this.onContinue,
  });

  @override
  State<SelectHabitsScreen> createState() => _SelectHabitsScreenState();
}

class _SelectHabitsScreenState extends State<SelectHabitsScreen> {
  late bool _water;
  late bool _sunlight;
  late bool _eyeRest;
  late bool _steps;

  @override
  void initState() {
    super.initState();
    _water = widget.initialWater;
    _sunlight = widget.initialSunlight;
    _eyeRest = widget.initialEyeRest;
    _steps = widget.initialSteps;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSizes.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.chooseWhatToTrack,
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 19.0,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              Text(
                AppStrings.chooseSubtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.p32),
              // Habit 1: Water
              _buildHabitCheckboxCard(
                icon: Icons.water_drop_rounded,
                iconColor: AppColors.waterPrimary,
                title: AppStrings.waterTitle,
                subtitle: AppStrings.habitWaterDesc,
                isSelected: _water,
                onTap: () => setState(() => _water = !_water),
                isDark: isDark,
              ),
              const SizedBox(height: AppSizes.p16),
              // Habit 2: Sunlight
              _buildHabitCheckboxCard(
                icon: Icons.wb_sunny_rounded,
                iconColor: AppColors.sunlightPrimary,
                title: AppStrings.sunlightTitle,
                subtitle: AppStrings.habitSunlightDesc,
                isSelected: _sunlight,
                onTap: () => setState(() => _sunlight = !_sunlight),
                isDark: isDark,
              ),
              const SizedBox(height: AppSizes.p16),
              // Habit 3: Eye Rest
              _buildHabitCheckboxCard(
                icon: Icons.remove_red_eye_rounded,
                iconColor: AppColors.eyePrimary,
                title: AppStrings.eyeRestTitle,
                subtitle: AppStrings.habitEyeRestDesc,
                isSelected: _eyeRest,
                onTap: () => setState(() => _eyeRest = !_eyeRest),
                isDark: isDark,
              ),
              const SizedBox(height: AppSizes.p16),
              // Habit 4: Steps
              _buildHabitCheckboxCard(
                icon: Icons.directions_run_rounded,
                iconColor: AppColors.movementPrimary,
                title: AppStrings.steps,
                subtitle: AppStrings.habitStepsDesc,
                isSelected: _steps,
                onTap: () => setState(() => _steps = !_steps),
                isDark: isDark,
              ),
              const Spacer(),
              // Continue Button
              SizedBox(
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSizes.borderRadiusMedium,
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => widget.onContinue(_water, _sunlight, _eyeRest, _steps),
                  child: Text(
                    AppStrings.continueBtn,
                    style: AppTextStyles.subheading.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitCheckboxCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardSurface : AppColors.surfaceSecondary,
          borderRadius: AppSizes.borderRadiusMedium,
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: AppSizes.iconLarge),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subheading.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.small.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? AppColors.primaryLight : AppColors.primary) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.borderLight),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
