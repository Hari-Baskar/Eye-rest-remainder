import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/system_screen_time_service.dart';
import '../../domain/entities/daily_rhythm_entity.dart';
import 'app_icon_badge.dart';

/// CumulativeAppUsageSection (Cardless, Naturally Floating Row of Vertically Separated Boxes)
///
/// Implements user requirements:
/// - Sits naturally directly on the surface (NO card container, NO card borders/background).
/// - No redundant subtitles: displays the row of app boxes directly.
/// - Filters out "Home Screen" / system launcher: shows real third-party apps only ("other only").
/// - Displays actual usage time for each app (e.g. "45m", "1h 20m").
class CumulativeAppUsageSection extends StatelessWidget {
  final DailyRhythmEntity rhythm;
  final List<AppCumulativeUsage>? customAppUsages;
  final bool isDark;
  final String title;
  final bool showTitle;
  final ValueChanged<AppCumulativeUsage?>? onAppSelected;
  final String? selectedPackage;
  final int? maxApps;

  const CumulativeAppUsageSection({
    super.key,
    required this.rhythm,
    this.customAppUsages,
    required this.isDark,
    this.title = "Today's App Usage",
    this.showTitle = false,
    this.onAppSelected,
    this.selectedPackage,
    this.maxApps,
  });

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final m = (totalSeconds + 30) ~/ 60;
    if (m < 60) {
      return '$m min';
    }
    final h = m ~/ 60;
    final remM = m % 60;
    if (remM == 0) return '${h}h';
    return '${h}h ${remM}m';
  }

  @override
  Widget build(BuildContext context) {
    final rawApps = customAppUsages ?? rhythm.effectiveAppUsages;
    final blueColor = AppColors.getRhythmBlue(isDark);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    // Filter out "Home Screen" / launchers - show other apps only
    final filteredApps = rawApps.where((app) {
      final lowerName = app.name.toLowerCase().trim();
      final lowerPkg = app.package.toLowerCase().trim();
      if (lowerName == 'home screen' ||
          lowerName == 'home' ||
          lowerName == 'screen active' ||
          lowerName == 'active session' ||
          lowerName.contains('launcher') ||
          lowerPkg.contains('launcher') ||
          lowerPkg.contains('systemui') ||
          lowerPkg == 'android') {
        return false;
      }
      return app.totalSeconds >= 5;
    }).toList();

    // Sort by usage time descending so top apps come first
    filteredApps.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));

    final apps = maxApps != null && maxApps! > 0
        ? filteredApps.take(maxApps!).toList()
        : filteredApps;

    if (apps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          // Section Header
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.subheading.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${apps.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // Natural Row of Vertically Separated Boxes (NO Card Container, NO redundant subtitles)
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = apps.length <= (maxApps != null ? maxApps! : 3);
            final minItemWidth = isCompact
                ? ((constraints.maxWidth - (apps.length - 1)) / max(1, apps.length)).clamp(85.0, double.infinity)
                : 90.0;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (int i = 0; i < apps.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 48,
                          color: dividerColor,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: minItemWidth,
                        ),
                        child: InkWell(
                          onTap: onAppSelected != null
                              ? () {
                                  final isSelected = selectedPackage != null &&
                                      (selectedPackage == apps[i].package ||
                                          (apps[i].package.isEmpty &&
                                              selectedPackage == apps[i].name));
                                  if (isSelected) {
                                    onAppSelected!(null);
                                  } else {
                                    onAppSelected!(apps[i]);
                                  }
                                }
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: (selectedPackage != null &&
                                      (selectedPackage == apps[i].package ||
                                          (apps[i].package.isEmpty &&
                                              selectedPackage == apps[i].name)))
                                  ? blueColor.withValues(
                                      alpha: isDark ? 0.22 : 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (selectedPackage != null &&
                                        (selectedPackage == apps[i].package ||
                                            (apps[i].package.isEmpty &&
                                                selectedPackage == apps[i].name)))
                                    ? blueColor
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // App Icon
                                AppIconBadge(
                                  packageName: apps[i].package,
                                  appName: apps[i].name,
                                  size: 32,
                                ),
                                const SizedBox(height: 7),
                                // App Name - Stretches horizontally to fit full name without ellipsis
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Text(
                                    apps[i].name.trim(),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textSlateNavy,
                                    ),
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Usage Time (e.g. "45 min", "1h 20m", "15s")
                                Text(
                                  _formatDuration(apps[i].totalSeconds),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: blueColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
