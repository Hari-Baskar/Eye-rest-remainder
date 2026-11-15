import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// WelcomeScreen
///
/// Screen 2 in the LifeMint onboarding flow.
/// Presents the 4 wellness habit pillars (Water, Sunlight, Eye Breaks, Movement),
/// and allows the user to begin onboarding or skip to the main dashboard.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSizes.p24),
              // Headline
              Text(
                AppStrings.welcomeTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 19.0,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p12),
              // Subtitle
              Text(
                AppStrings.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const Spacer(flex: 1),
              // Core Pillar Benefit Cards
              _buildBenefitRow(
                icon: Icons.remove_red_eye_rounded,
                iconColor: AppColors.eyePrimary,
                bgColor: isDark ? AppColors.eyeDarkBg : AppColors.eyeBackground,
                title: '20-20-20 Eye Rest & Strain Prevention',
                isDark: isDark,
              ),
              const SizedBox(height: AppSizes.p16),
              _buildBenefitRow(
                icon: Icons.hourglass_top_rounded,
                iconColor: AppColors.primary,
                bgColor: isDark ? AppColors.mintDarkBg : AppColors.mintAccent.withValues(alpha: 0.5),
                title: 'Mindful Screen Time & Break Reminders',
                isDark: isDark,
              ),
              const Spacer(flex: 2),
              // "Get Started" Button
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
                  onPressed: onGetStarted,
                  child: Text(
                    AppStrings.getStarted,
                    style: AppTextStyles.subheading.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              // "Skip for now" Button
              TextButton(
                onPressed: onSkip,
                child: Text(
                  AppStrings.skipForNow,
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardSurface : AppColors.surfaceSecondary,
        borderRadius: AppSizes.borderRadiusMedium,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.p8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: AppSizes.iconMedium),
          ),
          const SizedBox(width: AppSizes.p16),
          Text(
            title,
            style: AppTextStyles.subheading.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
