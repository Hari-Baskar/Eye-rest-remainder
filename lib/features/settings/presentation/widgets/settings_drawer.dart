import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/user_name_helper.dart';
import '../screens/settings_screen.dart';
import '../screens/settings_detail_screen.dart';
import '../screens/feedback_screen.dart';

/// SettingsDrawer
///
/// Custom drawer matching expense_tracker's AppDrawer design:
/// - Clean Forest Green top banner with personal app name (no sign-up, no email, no profile avatar).
/// - Surface-adaptive body (white in light mode, dark surface charcoal 0xFF2E2E2E in dark mode).
/// - Clean, unboxed minimalist list items with outline icons and 0.5px dividers.
/// - Opens dedicated full-page screens for Settings, Feedback, About, Privacy Policy, and Terms & Conditions.
class SettingsDrawer extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode mode) onThemeChanged;

  const SettingsDrawer({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  static const String aboutContent = '''
LifeMint v2.0.0

LifeMint is your personal wellness companion, designed to help you build healthier digital habits with ease.

Our app provides 20-20-20 eye strain protection, continuous screen time awareness, and mindful break reminders. Built with a commitment to privacy, all your habit summaries and usage data are processed and stored 100% locally on your device via SQLite.

Developed By : Praveen
''';

  static const String privacyPolicyContent = '''
Effective Date: November 1, 2026

LifeMint ("we", "our", or "the app") respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how LifeMint handles data.

1. 100% Local Processing & Storage
All wellness evaluations (continuous screen time tracking, daily eye rest break intervals, daily water logs, and movement stillness checks) are calculated in real time directly on your device.

2. Zero Third-Party Uploads
LifeMint does NOT transmit, sell, or upload your health or sensor data to third-party tracking servers or cloud platforms. Your data stays entirely on your device in a secure SQLite database.

3. Sensor & Permission Usage
- Notifications: Used strictly to send timely, user-configured reminders for eye breaks and continuous screen rest.
- Screen State: Detects screen-on sessions via local system broadcasts for optometry 20-20-20 eye strain guidance.
- Google Health Connect: Optionally syncs daily steps and walking distance with Google Fit.

4. Contact
For any privacy questions or requests, please use the Feedback section inside the app.
''';

  static const String termsAndConditionsContent = '''
Effective Date: November 1, 2026

By downloading, installing, or using LifeMint, you agree to be bound by these Terms & Conditions.

1. Wellness & Habit Disclaimer
LifeMint is a personal habit and wellness reminder utility designed to encourage healthy screen time, hydration, and eye rest habits. It is NOT a medical device, nor does it provide clinical diagnoses, ophthalmic treatment, or medical advice.

2. Personal Responsibility
Always consult a qualified healthcare professional or physician regarding eye disorders, vision fatigue, or hydration plans tailored to your medical profile.

3. Software Provided "As Is"
LifeMint is provided on an "as-is" and "as-available" basis without warranties of any kind. We strive to maintain continuous background accuracy while respecting operating system battery optimization standards.
''';

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  void _loadUserName() {
    setState(() {
      _userName = UserNameHelper.getName();
    });
  }

  void _showEditNameModal() {
    UserNameHelper.showEditNameModal(
      context,
      onNameChanged: (newName) {
        if (mounted) {
          setState(() {
            _userName = newName;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Drawer(
      backgroundColor: AppColors.getSurface(context),
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.78,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Forest Green Header Banner (Personal App - No profile avatar, no gmail)
            _buildProfileHeader(context),

            // 2. Scrollable List of Navigation Actions
            Expanded(
              child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
              children: [
                // Section 1: Settings
                _buildSimpleTile(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => SettingsScreen(
                          currentThemeMode: widget.currentThemeMode,
                          onThemeChanged: widget.onThemeChanged,
                        ),
                      ),
                    );
                  },
                ),

                _buildSectionDivider(context),

                // Section 2: Feedback, Share App, Rate App
                _buildSimpleTile(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Feedback',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const FeedbackScreen(),
                      ),
                    );
                  },
                ),
                _buildSimpleTile(
                  context,
                  icon: Icons.share_rounded,
                  title: 'Share App',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Sharing LifeMint Wellness...'),
                        backgroundColor: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _buildSimpleTile(
                  context,
                  icon: Icons.star_outline_rounded,
                  title: 'Rate App',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Thank you for supporting LifeMint! ⭐⭐⭐⭐⭐',
                        ),
                        backgroundColor: isDark
                            ? AppColors.primaryLight
                            : AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),

                _buildSectionDivider(context),

                // Section 3: About, Privacy Policy, Terms & Conditions
                _buildSimpleTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const SettingsDetailScreen(
                          title: 'About',
                          content: SettingsDrawer.aboutContent,
                        ),
                      ),
                    );
                  },
                ),
                _buildSimpleTile(
                  context,
                  icon: Icons.verified_user_outlined,
                  title: 'Privacy Policy',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const SettingsDetailScreen(
                          title: 'Privacy Policy',
                          content: SettingsDrawer.privacyPolicyContent,
                        ),
                      ),
                    );
                  },
                ),
                _buildSimpleTile(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const SettingsDetailScreen(
                          title: 'Terms & Conditions',
                          content: SettingsDrawer.termsAndConditionsContent,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.p16),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  /// Top Header Banner (Personal App Header - No email, No profile avatar, No edit icon, No subtitle)
  Widget _buildProfileHeader(BuildContext context) {
    final displayName = _userName.isNotEmpty ? _userName : 'LifeMint';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showEditNameModal,
      child: Container(
        width: double.infinity,
        color: AppColors.primary, // Deep rich forest green
        padding: EdgeInsets.fromLTRB(
          AppSizes.p20,
          MediaQuery.of(context).padding.top + AppSizes.p20,
          AppSizes.p20,
          AppSizes.p20,
        ),
        child: Text(
          displayName,
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Single drawer row item matching expense_tracker's _buildSimpleTile
  Widget _buildSimpleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);

    return ListTile(
      dense: true,
      minLeadingWidth: 0,
      horizontalTitleGap: 14,
      onTap: onTap,
      leading: Icon(
        icon,
        size: 20,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSectionDivider(BuildContext context) {
    return Divider(
      height: 16,
      thickness: 0.5,
      color: AppColors.getDivider(context),
    );
  }
}
