import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

/// Helper methods for formatting history dates, screen time, and eye breaks.
class DailyHistoryHelper {
  static String formatIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatDateTitle(String dateStr, String todayStr, String yesterdayStr) {
    if (dateStr == todayStr) {
      return 'Today';
    }
    if (dateStr == yesterdayStr) {
      return 'Yesterday';
    }
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  static String formatSubtitle(String dateStr, bool isToday, bool isYesterday) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return '';
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekday = weekdays[parsed.weekday - 1];
    if (isToday || isYesterday) {
      return '$weekday, ${months[parsed.month - 1]} ${parsed.day}';
    }
    return weekday;
  }

  static String formatScreenTime(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0m';
    }
    final totalMinutes = totalSeconds ~/ 60;
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    final hours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }

  static String formatBreaks(int breaks) {
    if (breaks == 1) {
      return '1 break';
    }
    return '$breaks breaks';
  }
}

/// DailyHistoryTile
///
/// Sleek, borderless list row displaying date, screen time, and eye breaks
/// matching the clean, toned-down aesthetic of expense_tracker.
class DailyHistoryTile extends StatelessWidget {
  final String dateTitle;
  final String weekdaySubtitle;
  final String screenTimeText;
  final String breaksText;
  final bool isToday;
  final bool isYesterday;
  final bool isDark;
  final bool showDivider;
  final VoidCallback? onTap;

  const DailyHistoryTile({
    super.key,
    required this.dateTitle,
    required this.weekdaySubtitle,
    required this.screenTimeText,
    required this.breaksText,
    required this.isToday,
    required this.isYesterday,
    required this.isDark,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          // Date Title & Weekday Subtitle (toned-down typography, no icons)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateTitle,
                      style: AppTextStyles.subheading.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.5,
                        color: isToday
                            ? (isDark ? AppColors.primaryLight : AppColors.primary)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Active',
                          style: AppTextStyles.small.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  weekdaySubtitle,
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Screen Time (hours used) & Breaks Taken Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                screenTimeText,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                breaksText,
                style: AppTextStyles.small.copyWith(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ],
        ],
      ),
    );

    Widget content = rowContent;

    if (onTap != null) {
      content = InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: rowContent,
      );
    }

    if (!showDivider) {
      return content;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        Divider(
          height: 1,
          thickness: 0.8,
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ],
    );
  }
}
