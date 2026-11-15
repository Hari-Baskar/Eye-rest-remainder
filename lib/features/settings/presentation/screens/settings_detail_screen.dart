import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';

/// SettingsDetailScreen
///
/// Dedicated full-page viewer for About, Privacy Policy, and Terms & Conditions.
/// Directly mirrors the layout and typography of expense_tracker's SettingsDetailScreen.
class SettingsDetailScreen extends StatelessWidget {
  final String title;
  final String content;

  const SettingsDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

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
          title,
          style: AppTextStyles.subheading.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p20,
            vertical: AppSizes.p16,
          ),
          child: _buildContent(context, isDark),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (title == 'About' && content.contains('Developed By:')) {
      final parts = content.split('Developed By:');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parts[0].trim(),
            style: AppTextStyles.body.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Developed By:${parts[1]}',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Text(
      content,
      style: AppTextStyles.body.copyWith(
        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        height: 1.6,
      ),
    );
  }
}

