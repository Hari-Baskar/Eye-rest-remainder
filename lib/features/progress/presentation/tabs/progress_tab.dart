import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/providers.dart';
import '../../domain/entities/daily_habit_summary_entity.dart';
import '../providers/progress_provider.dart';

/// ProgressTab
///
/// Clean Architecture presentation widget for the LifeMint Progress screen.
/// Displays a streamlined list of daily usage history:
/// - "Today" for current day
/// - "Yesterday" for the previous day
/// - Formatted date for older days (e.g. "Oct 22, 2026")
/// Each tile shows:
/// - Screen time used
/// - Number of breaks taken
class ProgressTab extends ConsumerWidget {
  final VoidCallback onOpenSettings;

  const ProgressTab({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final eyeRestState = ref.watch(eyeRestProvider);

    // Watch progressProvider so today's metrics stay synchronized in SQLite
    ref.watch(progressProvider);

    final now = DateTime.now();
    final todayStr = _formatIsoDate(now);
    final yesterdayStr = _formatIsoDate(now.subtract(const Duration(days: 1)));

    // Load all historical summaries ordered descending
    final rawSummaries = db.getAllDailySummariesDesc();

    // Map by date to guarantee uniqueness and live today values
    final Map<String, DailyHabitSummaryEntity> summaryMap = {
      for (final s in rawSummaries) s.date: s,
    };

    // Ensure today is always present and reflecting live values from eyeRestState
    final todaySummary = summaryMap[todayStr];
    summaryMap[todayStr] = DailyHabitSummaryEntity(
      date: todayStr,
      waterMl: todaySummary?.waterMl ?? 0,
      waterGoalMl: todaySummary?.waterGoalMl ?? 2500,
      sunlightMinutes: todaySummary?.sunlightMinutes ?? 0,
      sunlightGoalMinutes: todaySummary?.sunlightGoalMinutes ?? 20,
      eyeBreaks: max(todaySummary?.eyeBreaks ?? 0, eyeRestState.breaksTakenToday),
      eyeBreaksGoal: eyeRestState.recommendedBreaks,
      screenTimeSeconds: max(todaySummary?.screenTimeSeconds ?? 0, eyeRestState.totalDailyScreenSeconds),
      steps: todaySummary?.steps ?? 0,
      stepsGoal: todaySummary?.stepsGoal ?? 6000,
      overallScore: todaySummary?.overallScore ?? 0.0,
    );

    // Sort descending by date so Today is first, followed by Yesterday and earlier dates
    final sortedList = summaryMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          onPressed: onOpenSettings,
        ),
        title: Text(
          AppStrings.progressTitle,
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: sortedList.isEmpty
            ? _buildEmptyState(isDark)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.p16,
                  vertical: AppSizes.p12,
                ),
                itemCount: sortedList.length,
                itemBuilder: (context, index) {
                  final item = sortedList[index];
                  final isToday = item.date == todayStr;
                  final isYesterday = item.date == yesterdayStr;

                  final dateTitle = _formatDateTitle(item.date, todayStr, yesterdayStr);
                  final weekdaySubtitle = _formatSubtitle(item.date, isToday, isYesterday);
                  final screenTimeText = _formatScreenTime(item.screenTimeSeconds);
                  final breaksText = _formatBreaks(item.eyeBreaks);

                  return _buildDailyListTile(
                    context: context,
                    dateTitle: dateTitle,
                    weekdaySubtitle: weekdaySubtitle,
                    screenTimeText: screenTimeText,
                    breaksText: breaksText,
                    isToday: isToday,
                    isYesterday: isYesterday,
                    isDark: isDark,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDailyListTile({
    required BuildContext context,
    required String dateTitle,
    required String weekdaySubtitle,
    required String screenTimeText,
    required String breaksText,
    required bool isToday,
    required bool isYesterday,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardSurface : Colors.white,
        borderRadius: AppSizes.borderRadiusLarge,
        border: Border.all(
          color: isToday
              ? AppColors.primary.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.borderLight),
          width: isToday ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Leading Badge Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkBackground : AppColors.surfaceSecondary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isToday
                    ? Icons.today_rounded
                    : (isYesterday ? Icons.history_rounded : Icons.calendar_today_outlined),
                color: isToday
                    ? AppColors.primary
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Date Title & Day of Week Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateTitle,
                        style: AppTextStyles.subheading.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: isToday
                              ? (isDark ? AppColors.primaryLight : AppColors.primary)
                              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Active',
                            style: AppTextStyles.small.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    weekdaySubtitle,
                    style: AppTextStyles.small.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Screen Time & Breaks Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smartphone_rounded,
                      size: 15,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      screenTimeText,
                      style: AppTextStyles.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 14,
                      color: AppColors.eyePrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      breaksText,
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.eyePrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 56,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          const SizedBox(height: AppSizes.p16),
          Text(
            'No usage history yet',
            style: AppTextStyles.subheading.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.p8),
          Text(
            'Use your device to track daily screen time and breaks.',
            style: AppTextStyles.small.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTitle(String dateStr, String todayStr, String yesterdayStr) {
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

  String _formatSubtitle(String dateStr, bool isToday, bool isYesterday) {
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

  String _formatScreenTime(int totalSeconds) {
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

  String _formatBreaks(int breaks) {
    if (breaks == 1) {
      return '1 break';
    }
    return '$breaks breaks';
  }
}
