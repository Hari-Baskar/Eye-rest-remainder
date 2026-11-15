import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/utils/user_name_helper.dart';
import '../widgets/continuous_target_modal_sheet.dart';
import '../widgets/required_rest_modal_sheet.dart';

/// SettingsScreen
///
/// Clean, unboxed application settings screen matching expense_tracker's SettingsScreen:
/// - Seamless surface-based layout with AppColors.getBackground(context).
/// - Full-width switch and navigation tiles separated by 0.5px dividers.
/// - Controls for Display Name, Theme, Timer & Eye Care Settings, Permissions, and Background execution.
class SettingsScreen extends ConsumerStatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode mode) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  bool _notifAllowed = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _loadUserName();
  }

  void _loadUserName() {
    setState(() {
      _userName = UserNameHelper.getName();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    bool notifAllowed = false;
    try {
      final bool? nativeNotif =
          await const MethodChannel('com.reset/call_proximity')
              .invokeMethod<bool>('areNotificationsEnabled');
      if (nativeNotif != null) {
        notifAllowed = nativeNotif;
      } else {
        final plugin = FlutterLocalNotificationsPlugin();
        final bool? pluginNotif = await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
        notifAllowed = pluginNotif ?? false;
      }
    } catch (_) {
      try {
        final plugin = FlutterLocalNotificationsPlugin();
        final bool? pluginNotif = await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();
        notifAllowed = pluginNotif ?? false;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _notifAllowed = notifAllowed;
      });
    }
  }

  Future<void> _toggleNotificationPermission(bool targetValue) async {
    if (targetValue) {
      final plugin = FlutterLocalNotificationsPlugin();
      final granted = await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      if (granted == false) {
        try {
          await const MethodChannel('com.reset/call_proximity')
              .invokeMethod('openNotificationSettings');
        } catch (_) {}
      }
    } else {
      try {
        await const MethodChannel('com.reset/call_proximity')
            .invokeMethod('openNotificationSettings');
      } catch (_) {}
    }

    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final isDarkModeActive = widget.currentThemeMode == ThemeMode.dark ||
        (widget.currentThemeMode == ThemeMode.system && isDark);

    final rhythm = ref.watch(dailyRhythmProvider);
    final eyeRest = ref.watch(eyeRestProvider);

    final targetMins = rhythm.cycleTargetSeconds ~/ 60;
    final targetFormatted = rhythm.cycleTargetSeconds < 60
        ? '${rhythm.cycleTargetSeconds}s'
        : '$targetMins min';

    final restThresholdSec = rhythm.requiredRestSeconds;
    final restThresholdFormatted = restThresholdSec < 60
        ? '${restThresholdSec}s'
        : '${restThresholdSec ~/ 60} min';

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.subheading.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.p12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. Personalized Display Name
              _buildListTile(
                context,
                onTap: () {
                  UserNameHelper.showEditNameModal(
                    context,
                    onNameChanged: (val) {
                      if (mounted) {
                        setState(() => _userName = val);
                      }
                    },
                  );
                },
                title: Text(
                  'Display Name',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _userName.isNotEmpty ? _userName : 'Set name',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),

              _buildDivider(context),

              // 1. Dark Mode Quick Switch
              _buildSwitchTile(
                context,
                value: isDarkModeActive,
                onChanged: (val) {
                  widget.onThemeChanged(val ? ThemeMode.dark : ThemeMode.light);
                },
                title: Text(
                  isDarkModeActive ? 'Dark Mode' : 'Light Mode',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              _buildDivider(context),

              // 2. Timer & Eye Care Settings
              _buildListTile(
                context,
                onTap: () => ContinuousTargetModalSheet.show(context, rhythm),
                title: Text(
                  'Continuous Screen Target',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      targetFormatted,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),

              _buildDivider(context),

              _buildListTile(
                context,
                onTap: () => RequiredRestModalSheet.show(context, rhythm),
                title: Text(
                  'Required Rest Duration',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restThresholdFormatted,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),

              _buildDivider(context),

              _buildSwitchTile(
                context,
                value: eyeRest.isGamingDefenseEnabled,
                onChanged: (val) {
                  ref
                      .read(eyeRestProvider.notifier)
                      .setGamingDefenseEnabled(val);
                },
                title: Text(
                  'Smart Gaming Defense',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              _buildDivider(context),

              // 3. Permissions Preferences
              _buildSwitchTile(
                context,
                value: _notifAllowed,
                onChanged: (val) => _toggleNotificationPermission(val),
                title: Text(
                  'Notifications',
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              _buildDivider(context),

              const SizedBox(height: AppSizes.p28),

              // App Version
              Center(
                child: Text(
                  'Version 2.0.0',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.getTextMuted(context),
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.p24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required bool value,
    required ValueChanged<bool> onChanged,
    required Widget title,
    Widget? subtitle,
  }) {
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: AppSizes.p16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  subtitle,
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor:
                isDark ? AppColors.primaryLight : AppColors.primary,
            activeTrackColor:
                (isDark ? AppColors.primaryLight : AppColors.primary)
                    .withValues(alpha: 0.35),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppSizes.p16,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    subtitle,
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 16,
      thickness: 0.5,
      color: AppColors.getDivider(context),
    );
  }
}
