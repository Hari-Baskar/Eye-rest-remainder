import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reset/features/eye_rest/domain/entities/screen_activity_block.dart';
import 'package:reset/features/eye_rest/domain/entities/daily_rhythm_entity.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

import 'app_icon_badge.dart';

/// AlertWindowEvent
///
/// Minute-by-minute second-by-second event recorded during the observation window.
class AlertWindowEvent {
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String detail;
  final bool isRest;
  final bool isAlert;
  final bool hasBackgroundAudio;
  final String audioAppName;
  final String appPackage;
  final String appName;

  const AlertWindowEvent({
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.detail,
    this.isRest = false,
    this.isAlert = false,
    this.hasBackgroundAudio = false,
    this.audioAppName = '',
    this.appPackage = '',
    this.appName = '',
  });

  int get durationSeconds => max(0, endTime.difference(startTime).inSeconds);

  String get durationFormatted {
    final s = durationSeconds;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final rem = s % 60;
    if (rem == 0) return '${m}m';
    return '${m}m ${rem}s';
  }
}

/// AlertHighlightModel
///
/// Factual record of what happened when a 20m chime fired:
/// - Chime timestamp
/// - App active at that moment
/// - Reaction time (seconds until screen turned off)
/// - Total rest duration achieved during the custom rest window (+20s grace)
/// - Second-by-second window events
/// - Status: respected, partial, or ignored
class AlertHighlightModel {
  final DateTime alertTime;
  final String appName;
  final String appPackage;
  final int reactionSeconds;
  final int restSeconds;
  final int windowDurationSeconds;
  final bool hasBackgroundAudio;
  final String audioAppName;
  final AlertResponseStatus status;
  final List<AlertWindowEvent> windowEvents;

  const AlertHighlightModel({
    required this.alertTime,
    required this.appName,
    required this.appPackage,
    required this.reactionSeconds,
    required this.restSeconds,
    required this.windowDurationSeconds,
    required this.hasBackgroundAudio,
    required this.audioAppName,
    required this.status,
    required this.windowEvents,
  });

  static List<AlertHighlightModel> compute({
    required List<DateTime> alertTimestamps,
    required List<ScreenActivityBlock> blocks,
    required int requiredRestSeconds,
  }) {
    if (alertTimestamps.isEmpty || blocks.isEmpty) return const [];

    // Ensure sorted in ascending chronological order (earliest alert first)
    final sortedTimestamps = List<DateTime>.from(alertTimestamps)
      ..sort((a, b) => a.compareTo(b));

    final highlights = <AlertHighlightModel>[];
    const int kReactionGraceSeconds = 20; // 20s grace buffer after notification
    final windowDurationSeconds = requiredRestSeconds + kReactionGraceSeconds;

    for (final alertTime in sortedTimestamps) {
      final windowEnd = alertTime.add(Duration(seconds: windowDurationSeconds));

      // Find the screen block active at this alert timestamp
      int activeIndex = -1;
      for (int i = 0; i < blocks.length; i++) {
        final b = blocks[i];
        if (b.isActiveScreen &&
            !alertTime.isBefore(b.startTime) &&
            !alertTime.isAfter(b.endTime)) {
          activeIndex = i;
          break;
        }
      }

      // If alert was slightly after block end (within 45s margin)
      if (activeIndex == -1) {
        for (int i = 0; i < blocks.length; i++) {
          final b = blocks[i];
          if (b.isActiveScreen) {
            final diff = alertTime.difference(b.endTime).inSeconds.abs();
            if (diff <= 45) {
              activeIndex = i;
              break;
            }
          }
        }
      }

      final activeBlock = activeIndex != -1 ? blocks[activeIndex] : null;
      final topApp = activeBlock != null && activeBlock.topApps.isNotEmpty
          ? activeBlock.topApps.first
          : null;
      final appName = topApp?.name.isNotEmpty == true
          ? topApp!.name
          : 'Screen Active';
      final appPackage = topApp?.package ?? '';

      // Detailed events during this alert window
      final events = <AlertWindowEvent>[];

      // 1. Initial Alert point
      events.add(
        AlertWindowEvent(
          startTime: alertTime,
          endTime: alertTime,
          title: 'Alert Triggered',
          detail: 'Screen active on $appName',
          isAlert: true,
          appPackage: appPackage,
          appName: appName,
        ),
      );

      // 2. Scan overlapping blocks during [alertTime, windowEnd]
      int totalRestSec = 0;
      bool hasBgAudio = false;
      String audioApp = '';
      int? firstReactionSec;

      for (final b in blocks) {
        if (b.endTime.isBefore(alertTime) || b.startTime.isAfter(windowEnd)) {
          continue;
        }

        final effectiveStart =
            b.startTime.isBefore(alertTime) ? alertTime : b.startTime;
        final effectiveEnd =
            b.endTime.isAfter(windowEnd) ? windowEnd : b.endTime;
        final dur = effectiveEnd.difference(effectiveStart).inSeconds;
        if (dur <= 0) continue;

        if (!b.isActiveScreen) {
          // Phone Rest
          if (firstReactionSec == null) {
            final diff = b.startTime.difference(alertTime).inSeconds;
            firstReactionSec = diff > 0 ? diff : 0;
          }
          totalRestSec += dur;
          if (b.hasBackgroundAudio) {
            hasBgAudio = true;
            audioApp = b.audioAppName;
          }
          final durText = dur < 60
              ? '${dur}s'
              : '${dur ~/ 60}m ${dur % 60 > 0 ? "${dur % 60}s" : ""}';
          events.add(
            AlertWindowEvent(
              startTime: effectiveStart,
              endTime: effectiveEnd,
              title: b.hasBackgroundAudio && b.audioAppName.isNotEmpty
                  ? 'Eyes-Free Audio Rest ($durText)'
                  : 'Phone Rest ($durText)',
              detail: b.hasBackgroundAudio && b.audioAppName.isNotEmpty
                  ? 'Listening with screen locked (${b.audioAppName})'
                  : 'Display locked • Genuine physical rest',
              isRest: true,
              hasBackgroundAudio: b.hasBackgroundAudio,
              audioAppName: b.audioAppName,
              appName: b.hasBackgroundAudio && b.audioAppName.isNotEmpty
                  ? b.audioAppName
                  : 'Phone Rest',
            ),
          );
        } else {
          // Screen Active
          final name = b.topApps.isNotEmpty ? b.topApps.first.name : appName;
          final pkg = b.topApps.isNotEmpty ? b.topApps.first.package : appPackage;
          final durText = dur < 60
              ? '${dur}s'
              : '${dur ~/ 60}m ${dur % 60 > 0 ? "${dur % 60}s" : ""}';
          events.add(
            AlertWindowEvent(
              startTime: effectiveStart,
              endTime: effectiveEnd,
              title: '$name ($durText)',
              detail: 'Display on • Active use',
              isRest: false,
              appPackage: pkg,
              appName: name,
            ),
          );
        }
      }

      // If no rest block was found, check if activeBlock ended within window
      if (firstReactionSec == null &&
          activeBlock != null &&
          activeBlock.endTime.isAfter(alertTime)) {
        final endDiff = activeBlock.endTime.difference(alertTime).inSeconds;
        if (endDiff <= windowDurationSeconds) {
          firstReactionSec = endDiff;
        }
      }

      final reactionSec = firstReactionSec ?? windowDurationSeconds;

      // Status classification based on custom rest goal
      final AlertResponseStatus status;
      if (totalRestSec >= requiredRestSeconds) {
        status = AlertResponseStatus.respected;
      } else if (totalRestSec > 0) {
        status = AlertResponseStatus.partial;
      } else {
        status = AlertResponseStatus.ignored;
      }

      highlights.add(
        AlertHighlightModel(
          alertTime: alertTime,
          appName: appName,
          appPackage: appPackage,
          reactionSeconds: reactionSec,
          restSeconds: totalRestSec,
          windowDurationSeconds: windowDurationSeconds,
          hasBackgroundAudio: hasBgAudio,
          audioAppName: audioApp,
          status: status,
          windowEvents: events,
        ),
      );
    }

    highlights.sort((a, b) => a.alertTime.compareTo(b.alertTime));
    return highlights;
  }
}

enum AlertResponseStatus { respected, partial, ignored }

/// AlertHighlightsSection
///
/// Clean, minimal, non-dramatic presentation:
/// Shows Alerted Time, Activity during alert, and Rest Duration achieved according to user goal.
/// Tapping any row or arrow expands the second-by-second timeline of that alerted window.
class AlertHighlightsSection extends StatefulWidget {
  final List<DateTime> alertTimestamps;
  final List<ScreenActivityBlock> blocks;
  final DailyRhythmEntity? rhythm;
  final DateTime? date;
  final int requiredRestSeconds;
  final bool isDark;
  final bool showHeader;
  final ValueChanged<int>? onHourSelected;

  const AlertHighlightsSection({
    super.key,
    required this.alertTimestamps,
    required this.blocks,
    this.rhythm,
    this.date,
    required this.requiredRestSeconds,
    required this.isDark,
    this.showHeader = false,
    this.onHourSelected,
  });

  @override
  State<AlertHighlightsSection> createState() => _AlertHighlightsSectionState();
}

class _AlertHighlightsSectionState extends State<AlertHighlightsSection> {
  int? _expandedIndex;

  Widget _buildHelperMenuButton(bool isDark, String restFormatted) {
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<void>(
        tooltip: 'Alert guide',
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
        ),
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 280),
        itemBuilder: (ctx) => [
          PopupMenuItem<void>(
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 14,
                      color: AppColors.getRhythmBlue(isDark),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Alert & Rest Guide',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMenuBullet(
                  title: '20s Grace Period',
                  desc: 'Buffer after chime to finish reading and lock display.',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildMenuBullet(
                  title: '$restFormatted Rest Target',
                  desc: 'Phone rest & audio during this window are credited.',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildMenuBullet(
                  title: 'Tap Row to Expand',
                  desc: 'Inspect second-by-second events of that alert window.',
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBullet({
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• $title',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : AppColors.textPrimary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 1),
          child: Text(
            desc,
            style: TextStyle(
              fontSize: 10,
              height: 1.3,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlights = AlertHighlightModel.compute(
      alertTimestamps: widget.alertTimestamps,
      blocks: widget.blocks,
      requiredRestSeconds: widget.requiredRestSeconds,
    );

    if (highlights.isEmpty) return const SizedBox.shrink();

    final mintColor = AppColors.getRhythmGreen(widget.isDark);
    final amberColor = AppColors.getRhythmAmber(widget.isDark);
    final slateColor = AppColors.getRhythmSlate(widget.isDark);
    final blueColor = AppColors.getRhythmBlue(widget.isDark);
    final dividerColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    final restFormatted = widget.requiredRestSeconds < 60
        ? '${widget.requiredRestSeconds}s'
        : (widget.requiredRestSeconds % 60 == 0
            ? '${widget.requiredRestSeconds ~/ 60}m'
            : '${widget.requiredRestSeconds ~/ 60}m ${widget.requiredRestSeconds % 60}s');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          Text(
            'Alert History',
            style: AppTextStyles.subheading.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: widget.isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // 3-Column Table with Expandable Rows (Cardless / Pure Surface)
        Column(
          children: [
            _buildHeaderRow(widget.isDark, restFormatted),
            Divider(height: 10, thickness: 0.5, color: dividerColor),
            for (int i = 0; i < highlights.length; i++) ...[
              if (i > 0)
                Divider(height: 8, thickness: 0.5, color: dividerColor),
              _buildHighlightRow(
                i,
                highlights[i],
                widget.isDark,
                mintColor,
                amberColor,
                slateColor,
                blueColor,
                dividerColor,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderRow(bool isDark, String restFormatted) {
    final headerStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
    );
    final colDivider = Container(
      width: 0.8,
      height: 14,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 38,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Alerted Time',
                style: headerStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          colDivider,
          Expanded(
            flex: 16,
            child: Center(
              child: Text('App', style: headerStyle),
            ),
          ),
          colDivider,
          Expanded(
            flex: 34,
            child: Center(
              child: Text('Rest Duration', style: headerStyle),
            ),
          ),
          colDivider,
          SizedBox(
            width: 24,
            child: Center(
              child: _buildHelperMenuButton(isDark, restFormatted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(
    int index,
    AlertHighlightModel item,
    bool isDark,
    Color mintColor,
    Color amberColor,
    Color slateColor,
    Color blueColor,
    Color dividerColor,
  ) {
    final isExpanded = _expandedIndex == index;
    final timeStr = _formatTime(item.alertTime);

    // Rest duration formatting
    final String howLongStr;
    final Color howLongColor;
    final Color? howLongBg;
    if (item.status == AlertResponseStatus.ignored || item.restSeconds <= 0) {
      howLongStr = 'Continued';
      howLongColor =
          isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
      howLongBg = null;
    } else {
      final m = item.restSeconds ~/ 60;
      final s = item.restSeconds % 60;
      if (m == 0) {
        howLongStr = '${s}s';
      } else if (s == 0) {
        howLongStr = '${m}m';
      } else {
        howLongStr = '${m}m ${s}s';
      }

      if (item.hasBackgroundAudio) {
        howLongColor = blueColor;
        howLongBg = howLongColor.withValues(alpha: isDark ? 0.16 : 0.10);
      } else if (item.status == AlertResponseStatus.respected) {
        howLongColor = mintColor;
        howLongBg = mintColor.withValues(alpha: isDark ? 0.16 : 0.10);
      } else {
        howLongColor = amberColor;
        howLongBg = amberColor.withValues(alpha: isDark ? 0.16 : 0.10);
      }
    }

    final colDivider = Container(
      width: 0.8,
      height: 22,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
    );

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Alerted Time (includes seconds)
                Expanded(
                  flex: 38,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),

                colDivider,

                // 2. Activity during alert (App icon ONLY - no name)
                Expanded(
                  flex: 16,
                  child: Center(
                    child: AppIconBadge(
                      packageName: item.appPackage,
                      appName: item.appName,
                      size: 22,
                    ),
                  ),
                ),

                colDivider,

                // 3. Rest Duration according to custom target
                Expanded(
                  flex: 34,
                  child: Center(
                    child: howLongBg != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: howLongBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              howLongStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: howLongColor,
                              ),
                            ),
                          )
                        : Text(
                            howLongStr,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: howLongColor,
                            ),
                          ),
                  ),
                ),

                colDivider,

                // 4. Down Arrow (rotates when expanded)
                SizedBox(
                  width: 24,
                  child: Center(
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // If expanded: Minute-by-Minute details of that alerted window
            if (isExpanded)
              _buildExpandedWindowDetails(
                item,
                isDark,
                mintColor,
                amberColor,
                blueColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedWindowDetails(
    AlertHighlightModel item,
    bool isDark,
    Color mintColor,
    Color amberColor,
    Color blueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < item.windowEvents.length; i++) ...[
            Builder(
              builder: (context) {
                final ev = item.windowEvents[i];
                final isFirst = i == 0;
                final isLast = i == item.windowEvents.length - 1;

                if (ev.isAlert) {
                  return _buildTimelineItem(
                    isFirst: isFirst,
                    isLast: isLast,
                    node: _buildAlertTimelineNode(amberColor),
                    content: _buildCuteAlertContent(ev, amberColor),
                    isDark: isDark,
                  );
                } else if (ev.isRest) {
                  return _buildTimelineItem(
                    isFirst: isFirst,
                    isLast: isLast,
                    node: _buildRestTimelineNode(ev, mintColor, blueColor),
                    content: _buildCuteRestContent(ev, mintColor, blueColor),
                    isDark: isDark,
                  );
                } else {
                  return _buildTimelineItem(
                    isFirst: isFirst,
                    isLast: isLast,
                    node: _buildAppIconTimelineNode(ev, isDark),
                    content: _buildCuteAppContent(ev, blueColor, isDark),
                    isDark: isDark,
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Option 1 Connected Timeline Item (using IntrinsicHeight for unbroken vertical line)
  Widget _buildTimelineItem({
    required bool isFirst,
    required bool isLast,
    required Widget node,
    required Widget content,
    required bool isDark,
  }) {
    final lineColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.12,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left timeline column: line + node + line
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Top line connector
                SizedBox(
                  height: 2,
                  child: isFirst
                      ? null
                      : Center(child: Container(width: 1.5, color: lineColor)),
                ),
                // Node
                node,
                // Bottom line connector
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(child: Container(width: 1.5, color: lineColor)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 2 : 12),
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTimelineNode(Color amberColor) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: amberColor.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: amberColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.notifications_active_rounded,
        size: 15,
        color: amberColor,
      ),
    );
  }

  Widget _buildRestTimelineNode(
    AlertWindowEvent ev,
    Color mintColor,
    Color blueColor,
  ) {
    final color = ev.hasBackgroundAudio ? blueColor : mintColor;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        ev.hasBackgroundAudio ? Icons.headphones_rounded : Icons.spa_outlined,
        size: 15,
        color: color,
      ),
    );
  }

  Widget _buildAppIconTimelineNode(AlertWindowEvent ev, bool isDark) {
    final lowerName = ev.appName.toLowerCase();
    final lowerPkg = ev.appPackage.toLowerCase();
    final isHome = lowerName.contains('home') ||
        lowerPkg.contains('launcher') ||
        lowerPkg.contains('systemui') ||
        lowerName == 'screen active';

    if (isHome) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardSurface : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.home_rounded,
          size: 15,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
      );
    }

    return AppIconBadge(
      packageName: ev.appPackage,
      appName: ev.appName,
      size: 26,
    );
  }

  Widget _buildCuteAlertContent(
    AlertWindowEvent ev,
    Color amberColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _formatTime(ev.startTime),
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: amberColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: amberColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Alert',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: amberColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCuteRestContent(
    AlertWindowEvent ev,
    Color mintColor,
    Color blueColor,
  ) {
    final color = ev.hasBackgroundAudio ? blueColor : mintColor;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_formatTime(ev.startTime)} → ${_formatTime(ev.endTime)}',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            ev.durationFormatted,
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCuteAppContent(
    AlertWindowEvent ev,
    Color blueColor,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${_formatTime(ev.startTime)} → ${_formatTime(ev.endTime)}',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.textSlateNavy,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: blueColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            ev.durationFormatted,
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: blueColor,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute:$second $period';
  }
}
