import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/system_screen_time_service.dart'
    show AppCumulativeUsage, AppSessionInterval;
import '../../domain/entities/daily_rhythm_entity.dart';
import '../../domain/entities/screen_activity_block.dart';
import 'app_icon_badge.dart';
import 'cumulative_app_usage_section.dart';

/// DayHourSlice
///
/// Models a consistent, non-confusing clock-hour slice (e.g. 9 AM – 12 PM)
/// containing all activity, alert events, and rest periods recorded within that window.
class DayHourSlice {
  final int startHour;
  final int endHour;
  final String label;
  final String shortLabel;
  final List<ScreenActivityBlock> blocks;
  final int activeScreenSeconds;
  final int phoneRestSeconds;
  final int alertsCount;
  final int alertsRespondedCount;

  const DayHourSlice({
    required this.startHour,
    required this.endHour,
    required this.label,
    required this.shortLabel,
    required this.blocks,
    required this.activeScreenSeconds,
    required this.phoneRestSeconds,
    required this.alertsCount,
    required this.alertsRespondedCount,
  });

  bool get hasActiveScreen => activeScreenSeconds > 0;

  String get activeScreenFormatted {
    final m = activeScreenSeconds ~/ 60;
    if (m < 60) return m == 0 ? '${activeScreenSeconds}s' : '$m min';
    final h = m ~/ 60;
    final remM = m % 60;
    return remM == 0 ? '${h}h' : '${h}h ${remM}m';
  }

  String get phoneRestFormatted {
    final m = phoneRestSeconds ~/ 60;
    if (m < 60) return m == 0 ? '${phoneRestSeconds}s' : '$m min';
    final h = m ~/ 60;
    final remM = m % 60;
    return remM == 0 ? '${h}h' : '${h}h ${remM}m';
  }

  /// Derives cumulative app usage with intervals specifically for this hour slice
  List<AppCumulativeUsage> get sliceAppUsages {
    final Map<String, int> durationMap = {};
    final Map<String, String> nameMap = {};
    final Map<String, List<AppSessionInterval>> intervalMap = {};

    for (final block in blocks) {
      if (!block.isActiveScreen) continue;
      for (final app in block.topApps) {
        if (app.package.isEmpty && app.name.isEmpty) continue;
        final key = app.package.isNotEmpty ? app.package : app.name;
        nameMap[key] = app.name.isNotEmpty ? app.name : key;
        final dur = app.seconds > 0 ? app.seconds : block.durationSeconds;
        durationMap[key] = (durationMap[key] ?? 0) + dur;
        intervalMap.putIfAbsent(key, () => []).add(
          AppSessionInterval(
            startTime: block.startTime,
            endTime: block.endTime,
            durationSeconds: dur,
          ),
        );
      }
    }

    final list = durationMap.entries.map((e) {
      final key = e.key;
      return AppCumulativeUsage(
        name: nameMap[key] ?? key,
        package: key.contains('.') ? key : '',
        totalSeconds: e.value,
        intervals: intervalMap[key] ?? [],
      );
    }).toList();

    list.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
    return list;
  }

  /// Generates the day's standard 3-hour slices, filtering out future slices if viewing today
  /// and late-night zero-activity slices to keep the timeline calm and non-confusing.
  static List<DayHourSlice> generateSlices({
    required DateTime targetDate,
    required List<ScreenActivityBlock> allBlocks,
    required int cycleTargetSeconds,
  }) {
    const definitions = [
      (0, 3, '12 AM – 3 AM', '12a – 3a'),
      (3, 6, '3 AM – 6 AM', '3a – 6a'),
      (6, 9, '6 AM – 9 AM', '6a – 9a'),
      (9, 12, '9 AM – 12 PM', '9a – 12p'),
      (12, 15, '12 PM – 3 PM', '12p – 3p'),
      (15, 18, '3 PM – 6 PM', '3p – 6p'),
      (18, 21, '6 PM – 9 PM', '6p – 9p'),
      (21, 24, '9 PM – 12 AM', '9p – 12a'),
    ];

    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final currentHour = now.hour;

    final slices = <DayHourSlice>[];

    for (final def in definitions) {
      final startH = def.$1;
      final endH = def.$2;
      final label = def.$3;
      final shortLabel = def.$4;

      // Skip future slices for today
      if (isToday && startH > currentHour) {
        continue;
      }

      final sliceStart = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        startH,
      );
      final sliceEnd = endH == 24
          ? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999)
          : DateTime(targetDate.year, targetDate.month, targetDate.day, endH);

      // Collect blocks that overlap with this 3-hour window
      final sliceBlocks = allBlocks.where((b) {
        return b.endTime.isAfter(sliceStart) && b.startTime.isBefore(sliceEnd);
      }).toList();

      // Skip 12 AM – 6 AM slices if the phone was sleeping untouched
      if (sliceBlocks.isEmpty && endH <= 6) {
        continue;
      }

      int activeSec = 0;
      int restSec = 0;
      int alerts = 0;
      int responded = 0;

      for (final b in sliceBlocks) {
        if (b.isActiveScreen) {
          activeSec += b.durationSeconds;
          if (b.durationSeconds >= (cycleTargetSeconds * 0.90)) {
            alerts++;
            final alertTime = b.startTime.add(Duration(seconds: cycleTargetSeconds));
            final delaySec = b.endTime.difference(alertTime).inSeconds;
            if (delaySec <= 20) {
              responded++;
            }
          }
        } else {
          restSec += b.durationSeconds;
        }
      }

      slices.add(DayHourSlice(
        startHour: startH,
        endHour: endH,
        label: label,
        shortLabel: shortLabel,
        blocks: sliceBlocks,
        activeScreenSeconds: activeSec,
        phoneRestSeconds: restSec,
        alertsCount: alerts,
        alertsRespondedCount: responded,
      ));
    }

    return slices;
  }
}

/// HourSlicedStoryboard
///
/// Clean, cardless Storyboard using ONLY objective 3-hour time slices:
/// - Eliminates confusing arbitrary period names.
/// - Horizontal selector chips: "All Day", "6 AM – 9 AM", "9 AM – 12 PM", "12 PM – 3 PM", etc.
/// - Selecting a slice loads the focused, detailed timeline report for that exact window.
/// - Displays exact screen timing, alert prompt event (time & response speed), and rest reset verdict.
class HourSlicedStoryboard extends StatefulWidget {
  final DailyRhythmEntity rhythm;
  final List<ScreenActivityBlock> blocks;
  final DateTime date;
  final bool isToday;
  final bool isDark;
  final Color slateColor;
  final Color mintColor;
  final Color blueColor;
  final Color amberColor;
  final Color dividerColor;

  const HourSlicedStoryboard({
    super.key,
    required this.rhythm,
    required this.blocks,
    required this.date,
    required this.isToday,
    required this.isDark,
    required this.slateColor,
    required this.mintColor,
    required this.blueColor,
    required this.amberColor,
    required this.dividerColor,
  });

  @override
  State<HourSlicedStoryboard> createState() => _HourSlicedStoryboardState();
}

class _HourSlicedStoryboardState extends State<HourSlicedStoryboard> {
  int? _selectedSliceIndex; // null = All Day

  @override
  Widget build(BuildContext context) {
    if (widget.blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.nightlight_outlined,
                size: 34,
                color: widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                'No usage events logged for this date.',
                style: AppTextStyles.small.copyWith(
                  color: widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final slices = DayHourSlice.generateSlices(
      targetDate: widget.date,
      allBlocks: widget.blocks,
      cycleTargetSeconds: widget.rhythm.cycleTargetSeconds,
    );

    final isAllDay = _selectedSliceIndex == null || _selectedSliceIndex! >= slices.length;
    final currentSlice = isAllDay ? null : slices[_selectedSliceIndex!];
    final displayBlocks = isAllDay ? widget.blocks : currentSlice!.blocks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Horizontal Hour Slices Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // All Day Chip
              _buildSliceChip(
                isSelected: isAllDay,
                title: 'All Day',
                subtitle: widget.rhythm.activeScreenFormatted,
                onTap: () => setState(() => _selectedSliceIndex = null),
              ),
              const SizedBox(width: 8),

              // Slices Chips (6-9a, 9-12p, 12-3p, 3-6p, 6-9p, 9p-12a)
              for (int i = 0; i < slices.length; i++) ...[
                _buildSliceChip(
                  isSelected: _selectedSliceIndex == i,
                  title: slices[i].label,
                  subtitle: slices[i].hasActiveScreen
                      ? '${slices[i].activeScreenFormatted} • ${slices[i].alertsCount} alert${slices[i].alertsCount == 1 ? "" : "s"}'
                      : '🌿 Rest only',
                  onTap: () => setState(() => _selectedSliceIndex = i),
                ),
                if (i < slices.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Focused Slice Summary Header Banner
        _buildSliceSummaryBanner(
          isAllDay: isAllDay,
          slice: currentSlice,
        ),

        const SizedBox(height: 16),

        // 3. Focused Vertical Timeline for the Selected Hour Window
        if (displayBlocks.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.spa_outlined, size: 20, color: widget.mintColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Rested & Screen Locked',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No screen usage during this 3-hour window • Timer remained reset at 0',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          _buildSliceTimeline(
            blocks: displayBlocks,
            isAllDay: isAllDay,
            slice: currentSlice,
          ),
        ],

        const SizedBox(height: 24),
        Divider(height: 1, thickness: 0.7, color: widget.dividerColor),
        const SizedBox(height: 20),

        // 4. Cumulative App Usage Section for this view
        CumulativeAppUsageSection(
          rhythm: widget.rhythm,
          customAppUsages: isAllDay ? null : currentSlice!.sliceAppUsages,
          isDark: widget.isDark,
          title: isAllDay
              ? (widget.isToday ? "Today's App Usage" : "App Usage for This Day")
              : "${currentSlice!.label} App Usage",
        ),
      ],
    );
  }

  Widget _buildSliceChip({
    required bool isSelected,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final activeBg = widget.isDark ? Colors.white : const Color(0xFF1F1F1F);
    final activeText = widget.isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final inactiveBg = (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.04);
    final inactiveBorder = (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.09);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeBg : inactiveBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? activeText
                    : (widget.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? activeText.withValues(alpha: 0.82)
                    : (widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliceSummaryBanner({
    required bool isAllDay,
    required DayHourSlice? slice,
  }) {
    final title = isAllDay ? 'Full Day Story' : '${slice!.label} Activity Report';
    final screenFormatted = isAllDay ? widget.rhythm.activeScreenFormatted : slice!.activeScreenFormatted;
    final restFormatted = isAllDay ? widget.rhythm.phoneRestFormatted : slice!.phoneRestFormatted;
    final alertsCount = isAllDay ? widget.rhythm.remindersGiven : slice!.alertsCount;
    final respondedCount = isAllDay ? widget.rhythm.promptRestsCount : slice!.alertsRespondedCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              if (alertsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: widget.mintColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔔 $respondedCount / $alertsCount Responded',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: widget.mintColor,
                    ),
                  ),
                )
              else
                Text(
                  'No alerts fired',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMiniMetric('📱 Screen', screenFormatted, widget.slateColor),
              const SizedBox(width: 14),
              _buildMiniMetric('🌿 Phone Rest', restFormatted, widget.mintColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: widget.isDark ? Colors.white : const Color(0xFF1F1F1F),
          ),
        ),
      ],
    );
  }

  Widget _buildSliceTimeline({
    required List<ScreenActivityBlock> blocks,
    required bool isAllDay,
    required DayHourSlice? slice,
  }) {
    final firstBlock = blocks.first;
    final lastBlock = blocks.last;
    final targetMins = widget.rhythm.cycleTargetSeconds ~/ 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start Anchor Node
        _buildTimelineStep(
          isLast: false,
          node: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0),
              border: Border.all(
                color: widget.isDark ? Colors.white30 : Colors.black26,
                width: 2,
              ),
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Row(
              children: [
                Text(
                  _formatTime(firstBlock.startTime),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isAllDay ? '— Phone first unlocked (Day started)' : '— Slice started',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Session & Rest Blocks
        for (int i = 0; i < blocks.length; i++) ...[
          _buildBlockStep(
            block: blocks[i],
            isLast: i == blocks.length - 1 && !widget.isToday && isAllDay,
            targetMins: targetMins,
          ),
        ],

        // End Anchor Node
        if (isAllDay && widget.isToday)
          _buildTimelineStep(
            isLast: true,
            node: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.mintColor.withValues(alpha: 0.20),
                border: Border.all(color: widget.mintColor, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.mintColor,
                  ),
                ),
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Text(
                    'Now (${widget.rhythm.isScreenOn ? "Active" : "Resting"})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '— Continuing until lock/sleep',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildTimelineStep(
            isLast: true,
            node: Icon(
              Icons.done_all_rounded,
              size: 14,
              color: widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                children: [
                  Text(
                    _formatTime(lastBlock.endTime),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAllDay ? '— Day wrapped up' : '— Slice ended',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBlockStep({
    required ScreenActivityBlock block,
    required bool isLast,
    required int targetMins,
  }) {
    if (block.isActiveScreen) {
      // Screen Session Block
      final isMarathon = block.isOverrun || block.duration.inMinutes >= 35;
      final sessionColor = isMarathon ? widget.amberColor : widget.slateColor;

      return _buildTimelineStep(
        isLast: isLast,
        node: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: sessionColor.withValues(alpha: 0.16),
            border: Border.all(color: sessionColor, width: 1.5),
          ),
          child: Icon(
            isMarathon ? Icons.local_fire_department_rounded : Icons.check_rounded,
            size: 12,
            color: sessionColor,
          ),
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMarathon
                ? widget.amberColor.withValues(alpha: 0.05)
                : (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMarathon
                  ? widget.amberColor.withValues(alpha: 0.28)
                  : (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: exact duration + start/end time + target badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDuration(block.duration),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isMarathon
                              ? widget.amberColor
                              : (widget.isDark ? Colors.white : const Color(0xFF1F1F1F)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatTime(block.startTime)} → ${_formatTime(block.endTime)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (isMarathon)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.amberColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔥 Marathon',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: widget.amberColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.mintColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Within target',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: widget.mintColor,
                        ),
                      ),
                    ),
                ],
              ),

              // Apps Breakdown Pills
              if (block.topApps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: block.topApps.map((app) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIconBadge(
                            packageName: app.package,
                            appName: app.name,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${app.name} (${app.formattedDuration})',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Alert Prompt Event & User Response Timeline Badge
              if (block.durationSeconds >= (targetMins * 60 * 0.90)) ...[
                Builder(builder: (context) {
                  final targetSec = targetMins * 60;
                  final alertTime = block.startTime.add(Duration(seconds: targetSec));
                  final delaySec = block.endTime.difference(alertTime).inSeconds;
                  final respondedPromptly = delaySec <= 20;

                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: (respondedPromptly ? widget.mintColor : widget.amberColor)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (respondedPromptly ? widget.mintColor : widget.amberColor)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          respondedPromptly
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          size: 14,
                          color: respondedPromptly ? widget.mintColor : widget.amberColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            respondedPromptly
                                ? '🔔 Alert at ${_formatTime(alertTime)} • Responded in ${delaySec <= 2 ? "5" : delaySec}s → Screen locked'
                                : '🔔 Alert at ${_formatTime(alertTime)} • Postponed (+${_formatDuration(Duration(seconds: delaySec))} continued)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: respondedPromptly ? widget.mintColor : widget.amberColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (isMarathon) ...[
                const SizedBox(height: 6),
                Text(
                  '⚠️ Break prompt was postponed. Session continued without resting.',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.amberColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      // Rest Block
      final isAudioRest = block.hasBackgroundAudio;
      final isQualifiedReset = block.durationSeconds >= widget.rhythm.requiredRestSeconds;
      final restColor = isAudioRest ? widget.blueColor : widget.mintColor;

      return _buildTimelineStep(
        isLast: isLast,
        node: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: restColor.withValues(alpha: 0.14),
            border: Border.all(color: restColor, width: 1.5),
          ),
          child: Icon(
            isAudioRest ? Icons.headphones_rounded : Icons.spa_outlined,
            size: 10,
            color: restColor,
          ),
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: restColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: restColor.withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (isAudioRest && block.audioAppName.isNotEmpty) ...[
                        AppIconBadge(
                          packageName: '',
                          appName: block.audioAppName,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        Icon(
                          isAudioRest ? Icons.headphones_rounded : Icons.spa_outlined,
                          size: 13,
                          color: restColor,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Text(
                        _formatDuration(block.duration),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: restColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAudioRest
                            ? 'Eyes-Free ${block.audioAppName.isNotEmpty ? block.audioAppName : "Audio"}'
                            : 'Screen locked & resting',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: widget.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isQualifiedReset ? '✓ Reset' : 'Pause',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: restColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                isQualifiedReset
                    ? '✓ Full eye rest achieved • Continuous timer reset to 0'
                    : '⏸️ Short pause • Needed ${_formatDuration(Duration(seconds: widget.rhythm.requiredRestSeconds))} to reset timer',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isQualifiedReset
                      ? (widget.isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)
                      : (widget.isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTimelineStep({
    required Widget node,
    required Widget content,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                node,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final m = d.inMinutes;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final remM = m % 60;
    return remM == 0 ? '${h}h' : '${h}h ${remM}m';
  }
}
