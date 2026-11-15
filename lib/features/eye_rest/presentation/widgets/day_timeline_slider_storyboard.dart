import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/entities/daily_rhythm_entity.dart';
import '../../domain/entities/screen_activity_block.dart';
import 'app_icon_badge.dart';

/// DayTimelineSlice
///
/// Data model representing a single continuous active or rest period for the slide.
class DayTimelineSlice {
  final int id;
  final DateTime startTime;
  final DateTime endTime;
  final ActivityType type;
  final int durationSeconds;
  final List<AppUsageSnippet> apps;
  final bool hasAlert;
  final DateTime? alertTime;
  final String? alertReason;

  const DayTimelineSlice({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.durationSeconds,
    this.apps = const [],
    this.hasAlert = false,
    this.alertTime,
    this.alertReason,
  });

  bool get isActiveScreen => type == ActivityType.activeScreen;
  bool get isPhoneRest => type == ActivityType.phoneRest;

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    if (m < 1) return '${durationSeconds}s';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}m';
  }

  String get startFormatted => _formatTime(startTime);
  String get endFormatted => _formatTime(endTime);
  String get timeRangeFormatted => '$startFormatted → $endFormatted';

  static String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:$m $period';
  }
}

/// DayTimelineSliderStoryboard
///
/// Clean, focused Timeline Slide + Detail Card layout:
/// 1. Continuous full-width day slide with Blue (active) & Green (rest) fillers.
/// 2. Amber alert markers directly on the slide at the exact moments Reset alerted the user.
/// 3. Dual navigation: Smooth thumb drag with magnetic snapping + Previous/Next step buttons.
/// 4. Total slices counter (e.g. "Slice 18 of 38").
/// 5. Single focused Information Card directly below showing active apps or rest recovery.
class DayTimelineSliderStoryboard extends StatefulWidget {
  final DailyRhythmEntity rhythm;
  final List<ScreenActivityBlock> blocks;
  final DateTime date;
  final bool isToday;
  final List<DateTime> alertTimestamps;
  final bool isDark;
  final Color slateColor;
  final Color mintColor;
  final Color blueColor;
  final Color amberColor;
  final Color dividerColor;

  const DayTimelineSliderStoryboard({
    super.key,
    required this.rhythm,
    required this.blocks,
    required this.date,
    required this.isToday,
    this.alertTimestamps = const [],
    required this.isDark,
    required this.slateColor,
    required this.mintColor,
    required this.blueColor,
    required this.amberColor,
    required this.dividerColor,
  });

  @override
  State<DayTimelineSliderStoryboard> createState() =>
      _DayTimelineSliderStoryboardState();
}

class _DayTimelineSliderStoryboardState
    extends State<DayTimelineSliderStoryboard> {
  int _selectedIndex = 0;
  List<DayTimelineSlice> _slices = [];
  int _totalDaySeconds = 0;
  DateTime? _dayStart;
  DateTime? _dayEnd;

  @override
  void initState() {
    super.initState();
    _buildSlices();
    // Default to the last slice (most recent) if today, or first active slice
    if (_slices.isNotEmpty) {
      if (widget.isToday) {
        _selectedIndex = _slices.length - 1;
      } else {
        final firstActive = _slices.indexWhere((s) => s.isActiveScreen);
        _selectedIndex = firstActive != -1 ? firstActive : 0;
      }
    }
  }

  @override
  void didUpdateWidget(DayTimelineSliderStoryboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks ||
        oldWidget.alertTimestamps != widget.alertTimestamps) {
      _buildSlices();
      if (_selectedIndex >= _slices.length) {
        _selectedIndex = max(0, _slices.length - 1);
      }
    }
  }

  void _buildSlices() {
    final rawBlocks = widget.blocks
        .where((b) => b.durationSeconds >= 5)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (rawBlocks.isEmpty) {
      _slices = [];
      _totalDaySeconds = 0;
      return;
    }

    _dayStart = rawBlocks.first.startTime;
    _dayEnd = rawBlocks.last.endTime;

    final targetCycleSec = widget.rhythm.cycleTargetSeconds;
    final generated = <DayTimelineSlice>[];
    int totalSec = 0;

    for (int i = 0; i < rawBlocks.length; i++) {
      final b = rawBlocks[i];
      final durSec = max(5, b.durationSeconds);
      totalSec += durSec;

      // Determine if an alert was triggered in this session
      bool hasAlert = false;
      DateTime? alertTime;
      String? alertReason;

      // Check against explicit alert timestamps
      for (final ts in widget.alertTimestamps) {
        if (!ts.isBefore(b.startTime) && !ts.isAfter(b.endTime)) {
          hasAlert = true;
          alertTime = ts;
          alertReason =
              'Continuous screen time reached ${targetCycleSec ~/ 60}m';
          break;
        }
      }

      // Fallback: If duration met/exceeded cycle target and is active screen
      if (!hasAlert &&
          b.isActiveScreen &&
          durSec >= (targetCycleSec * 0.95)) {
        hasAlert = true;
        alertTime = b.startTime.add(Duration(seconds: targetCycleSec));
        alertReason =
            'Continuous screen threshold reached (${targetCycleSec ~/ 60}m)';
      }

      generated.add(
        DayTimelineSlice(
          id: i,
          startTime: b.startTime,
          endTime: b.endTime,
          type: b.type,
          durationSeconds: durSec,
          apps: b.topApps,
          hasAlert: hasAlert,
          alertTime: alertTime,
          alertReason: alertReason,
        ),
      );
    }

    _slices = generated;
    _totalDaySeconds = max(1, totalSec);
  }

  void _selectSlice(int index) {
    if (index >= 0 && index < _slices.length && index != _selectedIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _handleDragPosition(double localX, double totalWidth) {
    if (_slices.isEmpty || totalWidth <= 0) return;
    final clampedX = localX.clamp(0.0, totalWidth);
    final ratio = clampedX / totalWidth;
    final targetSec = ratio * _totalDaySeconds;

    int accum = 0;
    for (int i = 0; i < _slices.length; i++) {
      accum += _slices[i].durationSeconds;
      if (targetSec <= accum) {
        _selectSlice(i);
        break;
      }
    }
  }

  double _getSliceCenterRatio(int index) {
    if (_slices.isEmpty || _totalDaySeconds <= 0) return 0.0;
    int accum = 0;
    for (int i = 0; i < index; i++) {
      accum += _slices[i].durationSeconds;
    }
    accum += _slices[index].durationSeconds ~/ 2;
    return (accum / _totalDaySeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_slices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        child: Text(
          'No activity recorded for this date yet.',
          style: AppTextStyles.small.copyWith(
            color: widget.isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      );
    }

    final currentSlice = _slices[_selectedIndex];
    final totalActiveSlices = _slices.where((s) => s.isActiveScreen).length;
    final totalRestSlices = _slices.where((s) => s.isPhoneRest).length;
    final totalAlerts = _slices.where((s) => s.hasAlert).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Row: Slice Index + Step Buttons (‹ Prev / Next ›)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Current Slice Badge & Alerts
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (widget.isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${_selectedIndex + 1} • ${currentSlice.startFormatted}',
                      style: AppTextStyles.small.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (totalAlerts > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.amberColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.amberColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 11,
                            color: widget.amberColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$totalAlerts alert${totalAlerts > 1 ? "s" : ""}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.amberColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Right: Step Buttons (Move with button)
            Row(
              children: [
                Text(
                  'Slice ${_selectedIndex + 1}/${_slices.length}',
                  style: AppTextStyles.small.copyWith(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // Prev Button
                IconButton.filledTonal(
                  onPressed: _selectedIndex > 0
                      ? () => _selectSlice(_selectedIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: (widget.isDark
                            ? Colors.white
                            : Colors.black)
                        .withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(width: 4),
                // Next Button
                IconButton.filled(
                  onPressed: _selectedIndex < _slices.length - 1
                      ? () => _selectSlice(_selectedIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: widget.blueColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. THE TIMELINE SLIDE BAR (Continuous Full-Width + Thumb Scrubber)
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final thumbRatio = _getSliceCenterRatio(_selectedIndex);
            final thumbX = (thumbRatio * barWidth).clamp(6.0, barWidth - 6.0);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onHorizontalDragStart: (details) =>
                      _handleDragPosition(details.localPosition.dx, barWidth),
                  onHorizontalDragUpdate: (details) =>
                      _handleDragPosition(details.localPosition.dx, barWidth),
                  onTapDown: (details) =>
                      _handleDragPosition(details.localPosition.dx, barWidth),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF0F141C)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (widget.isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.12),
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Colored Slices Segments
                        ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Row(
                            children: _slices.map((slice) {
                              final flex = max(
                                1,
                                (slice.durationSeconds * 1000) ~/
                                    _totalDaySeconds,
                              );
                              final isSelected = slice.id == currentSlice.id;
                              final segColor = slice.isActiveScreen
                                  ? (isSelected
                                      ? widget.blueColor
                                      : widget.blueColor.withValues(alpha: 0.70))
                                  : (isSelected
                                      ? widget.mintColor
                                      : widget.mintColor.withValues(alpha: 0.55));

                              return Expanded(
                                flex: flex,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: segColor,
                                    border: Border(
                                      right: BorderSide(
                                        color: widget.isDark
                                            ? Colors.black.withValues(alpha: 0.40)
                                            : Colors.white.withValues(alpha: 0.60),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: slice.hasAlert
                                      ? Center(
                                          child: Container(
                                            width: 3,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: widget.amberColor,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: widget.amberColor
                                                      .withValues(alpha: 0.9),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Thumb Needle Handle (Moves smoothly with thumb drag or buttons)
                        Positioned(
                          left: thumbX - 2,
                          top: -3,
                          bottom: -3,
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.50),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Top grip circle
                                Positioned(
                                  top: -4,
                                  left: -5,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.blueColor,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.blueColor
                                              .withValues(alpha: 0.40),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Bottom grip circle
                                Positioned(
                                  bottom: -4,
                                  left: -5,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.blueColor,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Clock Hour Labels along Bottom
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dayStart != null
                          ? DayTimelineSlice._formatTime(_dayStart!)
                          : 'Morning',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: widget.isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      '12 PM',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: widget.isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                    Text(
                      _dayEnd != null
                          ? DayTimelineSlice._formatTime(_dayEnd!)
                          : 'Night',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: widget.isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 10),

        // 3. Legend & Total Slices Summary
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildLegendItem(
                  color: widget.blueColor,
                  label: 'Active ($totalActiveSlices)',
                ),
                const SizedBox(width: 12),
                _buildLegendItem(
                  color: widget.mintColor,
                  label: 'Rested ($totalRestSlices)',
                ),
                if (totalAlerts > 0) ...[
                  const SizedBox(width: 12),
                  _buildLegendItem(
                    color: widget.amberColor,
                    label: 'Alerts ($totalAlerts)',
                  ),
                ],
              ],
            ),
            Text(
              '${_slices.length} slices total',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: widget.isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 4. THE INFORMATION CARD (Focused Inspection - No Extra Lists!)
        _buildInformationCard(currentSlice),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: widget.isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInformationCard(DayTimelineSlice slice) {
    final isActive = slice.isActiveScreen;
    final primaryColor = isActive ? widget.blueColor : widget.mintColor;

    return Container(
      decoration: BoxDecoration(
        color: (widget.isDark ? Colors.white : Colors.black)
            .withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon + Title + Duration
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isActive
                      ? Icons.smartphone_rounded
                      : Icons.spa_outlined,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isActive
                              ? 'ACTIVE SCREEN SESSION'
                              : 'PHONE RESTED PERIOD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• Slice ${slice.id + 1} of ${_slices.length}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            color: widget.isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slice.timeRangeFormatted,
                      style: AppTextStyles.subheading.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1F1F1F),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    slice.durationFormatted,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    isActive ? 'screen time' : 'eye recovery',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: widget.isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Alert Callout Banner (If Alert Triggered in this slice)
          if (slice.hasAlert) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.amberColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.amberColor.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: widget.amberColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slice.alertTime != null
                              ? 'Alert Shown at ${DayTimelineSlice._formatTime(slice.alertTime!)}'
                              : 'Eye Break Alert Shown',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.amberColor,
                          ),
                        ),
                        if (slice.alertReason != null)
                          Text(
                            slice.alertReason!,
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(height: 1, thickness: 0.6, color: widget.dividerColor),
          const SizedBox(height: 12),

          // Content: Apps Used (Active) vs Rest Info (Rest)
          if (isActive)
            _buildActiveAppsSection(slice)
          else
            _buildRestRechargeSection(slice),
        ],
      ),
    );
  }

  Widget _buildActiveAppsSection(DayTimelineSlice slice) {
    if (slice.apps.isEmpty) {
      return Text(
        'Phone was actively used during this continuous period.',
        style: TextStyle(
          fontSize: 12,
          color: widget.isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What was used during this slice:',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: widget.isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slice.apps.map((app) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (widget.isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (widget.isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconBadge(
                    packageName: app.package,
                    appName: app.name,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    app.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    app.formattedDuration,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: widget.blueColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRestRechargeSection(DayTimelineSlice slice) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: 16,
          color: widget.mintColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eyes Rested & Relaxed',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: widget.mintColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Screen was continuously off from ${slice.startFormatted} to ${slice.endFormatted}. Your eyes rested for ${slice.durationFormatted}, completely resetting your continuous screen timer to 0.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

