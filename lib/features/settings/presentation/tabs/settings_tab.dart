import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// SettingsTab
///
/// Screen 15 in the LifeMint design suite.
/// Provides configuration for Daily goals, Reminders, Permissions,
/// Appearance theme selector (Light, Dark, System), Health Connect connection, and feedback.
class SettingsTab extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode mode) onThemeChanged;
  final VoidCallback onOpenDailyGoals;
  final VoidCallback? onOpenManageHabits;
  final VoidCallback onOpenPermissions;
  final VoidCallback onOpenHealthConnect;
  final VoidCallback onRestartOnboarding;

  const SettingsTab({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    required this.onOpenDailyGoals,
    this.onOpenManageHabits,
    required this.onOpenPermissions,
    required this.onOpenHealthConnect,
    required this.onRestartOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        title: Text(
          AppStrings.settingsTitle,
          style: AppTextStyles.subheading.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSizes.screenPadding,
          child: Column(
            children: [
              _buildSettingsCard(
                context: context,
                isDark: isDark,
                children: [
                  _buildSettingsRow(
                    icon: Icons.track_changes_rounded,
                    iconColor: AppColors.waterPrimary,
                    title: AppStrings.dailyGoals,
                    onTap: onOpenDailyGoals,
                    isDark: isDark,
                  ),
                  if (onOpenManageHabits != null) ...[
                    _buildDivider(isDark),
                    _buildSettingsRow(
                      icon: Icons.checklist_rounded,
                      iconColor: AppColors.primaryLight,
                      title: 'Active Habits & Dashboard',
                      onTap: onOpenManageHabits!,
                      isDark: isDark,
                    ),
                  ],
                  _buildDivider(isDark),
                  _buildSettingsRow(
                    icon: Icons.notifications_none_rounded,
                    iconColor: AppColors.sunlightPrimary,
                    title: AppStrings.reminders,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications are active in background.')),
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsRow(
                    icon: Icons.verified_user_outlined,
                    iconColor: AppColors.eyePrimary,
                    title: AppStrings.permissions,
                    onTap: onOpenPermissions,
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsRow(
                    icon: Icons.brightness_6_outlined,
                    iconColor: AppColors.movementPrimary,
                    title: AppStrings.appearance,
                    trailingText: _getThemeName(currentThemeMode),
                    onTap: () => _showThemeModal(context, isDark),
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsRow(
                    icon: Icons.favorite_rounded,
                    iconColor: AppColors.alert,
                    title: AppStrings.healthConnectTitle,
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.healthConnectConnected,
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      ],
                    ),
                    onTap: onOpenHealthConnect,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p20),
              _buildSettingsCard(
                context: context,
                isDark: isDark,
                children: [
                  _buildSettingsRow(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.textSecondary,
                    title: AppStrings.about,
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: AppStrings.appName,
                        applicationVersion: '2.0.0',
                        applicationLegalese: 'LifeMint - Small steps, A healthier you.',
                      );
                    },
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildSettingsRow(
                    icon: Icons.mail_outline_rounded,
                    iconColor: AppColors.textSecondary,
                    title: AppStrings.sendFeedback,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feedback form opened.')),
                      );
                    },
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p24),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppStrings.themeLight;
      case ThemeMode.dark:
        return AppStrings.themeDark;
      case ThemeMode.system:
        return AppStrings.themeSystem;
    }
  }

  void _showThemeModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCardSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: AppSizes.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : AppColors.borderLight,
                  borderRadius: AppSizes.borderRadiusPill,
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              Text(
                AppStrings.appearance,
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p16),
              _buildThemeOption(ctx, AppStrings.themeLight, Icons.light_mode_rounded, ThemeMode.light, isDark),
              _buildThemeOption(ctx, AppStrings.themeDark, Icons.dark_mode_rounded, ThemeMode.dark, isDark),
              _buildThemeOption(ctx, AppStrings.themeSystem, Icons.phone_android_rounded, ThemeMode.system, isDark),
              const SizedBox(height: AppSizes.p16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.r8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    AppStrings.done,
                    style: AppTextStyles.subheading.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, IconData icon, ThemeMode mode, bool isDark) {
    final isSelected = currentThemeMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.r8),
      onTap: () {
        onThemeChanged(mode);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required BuildContext context, required List<Widget> children, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCardSurface(context),
        borderRadius: BorderRadius.circular(AppSizes.r8),
        border: AppColors.getCardBorder(context),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.r8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailingText != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailingText,
                    style: AppTextStyles.small.copyWith(
                      fontWeight: FontWeight.w300,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary, size: 18),
                ],
              )
            else
              Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 52,
      endIndent: 14,
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}
