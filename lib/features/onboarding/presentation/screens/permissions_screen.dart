import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';

/// PermissionsScreen
///
/// Screen 5 in the LifeMint onboarding flow.
/// Guides the user through granting essential background permissions
/// (Notifications and Usage Access) with intuitive "Allow >" rows.
class PermissionsScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionsScreen({super.key, required this.onComplete});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _notifAllowed = false;
  bool _batteryExempt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBatteryOptimization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryOptimization();
    }
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      final bool? exempt = await const MethodChannel('com.reset/call_proximity')
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      if (mounted) {
        setState(() {
          _batteryExempt = exempt ?? false;
        });
      }
    } catch (_) {}
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
                AppStrings.allowPermissionsTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 19.0,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              Text(
                AppStrings.allowPermissionsSubtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.p24),
              // Permission 1: Notifications
              _buildPermissionItem(
                icon: Icons.notifications_active_rounded,
                iconColor: AppColors.sunlightPrimary,
                title: AppStrings.permNotifications,
                desc: AppStrings.permNotificationsDesc,
                isAllowed: _notifAllowed,
                onTap: () async {
                  final plugin = FlutterLocalNotificationsPlugin();
                  final granted = await plugin
                      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                      ?.requestNotificationsPermission();
                  setState(() => _notifAllowed = granted ?? true);
                },
                isDark: isDark,
              ),
              const SizedBox(height: AppSizes.p12),
              // Permission 2: Unrestricted Background (Battery Optimization Exemption)
              _buildPermissionItem(
                icon: Icons.battery_charging_full_rounded,
                iconColor: AppColors.primary,
                title: 'Unrestricted Background',
                desc: 'Exempts LifeMint from battery optimization for reliable, uninterrupted eye strain protection',
                isAllowed: _batteryExempt,
                onTap: () async {
                  try {
                    await const MethodChannel('com.reset/call_proximity')
                        .invokeMethod('requestIgnoreBatteryOptimizations');
                  } catch (_) {}
                },
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
                  onPressed: widget.onComplete,
                  child: Text(
                    AppStrings.continueBtn,
                    style: AppTextStyles.subheading.copyWith(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.p8),
              // "I'll do this later"
              TextButton(
                onPressed: widget.onComplete,
                child: Text(
                  AppStrings.illDoThisLater,
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

  Widget _buildPermissionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required bool isAllowed,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardSurface : AppColors.surfaceSecondary,
          borderRadius: AppSizes.borderRadiusMedium,
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
                    desc,
                    style: AppTextStyles.small.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isAllowed ? AppStrings.allowed : '${AppStrings.allow} >',
              style: AppTextStyles.small.copyWith(
                color: isAllowed
                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
