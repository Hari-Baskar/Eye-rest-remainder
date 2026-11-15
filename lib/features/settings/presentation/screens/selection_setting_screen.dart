import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_text_styles.dart';

class SelectionOption {
  final String value;
  final String label;
  final IconData icon;

  const SelectionOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// SelectionSettingScreen
///
/// Clean radio-selection setting screen matching expense_tracker's SelectionSettingScreen.
/// Used for theme mode selection and single-choice settings.
class SelectionSettingScreen extends StatelessWidget {
  final String title;
  final List<SelectionOption> options;
  final String currentValue;
  final Function(String) onSelected;

  const SelectionSettingScreen({
    super.key,
    required this.title,
    required this.options,
    required this.currentValue,
    required this.onSelected,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(AppSizes.r12),
            border: AppColors.getCardBorder(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              final isLast = idx == options.length - 1;
              final isSelected = option.value == currentValue;

              return Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      onSelected(option.value);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.p20,
                        vertical: AppSizes.p16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option.icon,
                            color: isSelected
                                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            size: 22,
                          ),
                          const SizedBox(width: AppSizes.p16),
                          Expanded(
                            child: Text(
                              option.label,
                              style: AppTextStyles.body.copyWith(
                                color: isSelected
                                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.getDivider(context),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

