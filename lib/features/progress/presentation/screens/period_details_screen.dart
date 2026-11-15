import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reset/features/eye_rest/domain/entities/screen_activity_block.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/system_screen_time_service.dart';
import '../../../eye_rest/presentation/widgets/app_icon_badge.dart';
import '../../../eye_rest/presentation/widgets/day_rhythm_detail_sheet.dart';
import '../../domain/entities/history_records.dart';
import '../widgets/daily_history_tile.dart';

/// PeriodDetailsScreen
///
/// Clean, cohesive report for a selected Week or Month:
/// - Follows the exact visual language of the Main Dashboard.
/// - Weekly: 7 Day Water Glasses (Mon–Sun).
/// - Monthly: 4–5 Row Calendar Grid of Day Capsules (Option B).
/// - App Filter: Tapping any app turns the board into that app's daily heatmap.
/// - Day Spotlight Card: Tapping any capsule shows that day's summary with a jump to its 24h Storyboard.
class PeriodDetailsScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final int totalPhoneSeconds;
  final int totalRestSeconds;
  final int avgPhoneSeconds;
  final int avgRestSeconds;
  final int alertsCount;
  final dynamic peakStrain; // Kept for constructor compatibility
  final List<dynamic> apps; // List<AppUsageSnippet>
  final List<DailyHistoryRecord>? days;
  final List<WeeklyHistoryRecord>? weeks;
  final DateTime? monthDate;
  final AppDatabase db;

  const PeriodDetailsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.totalPhoneSeconds,
    required this.totalRestSeconds,
    required this.avgPhoneSeconds,
    required this.avgRestSeconds,
    this.alertsCount = 0,
    this.peakStrain,
    required this.apps,
    this.days,
    this.weeks,
    this.monthDate,
    required this.db,
  });

  static void showWeekly({
    required BuildContext context,
    required WeeklyHistoryRecord record,
    required AppDatabase db,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeriodDetailsScreen(
          title: record.title,
          subtitle: record.dateRangeStr,
          totalPhoneSeconds: record.totalPhoneSeconds,
          totalRestSeconds: record.totalRestSeconds,
          avgPhoneSeconds: record.avgPhoneSecondsPerDay,
          avgRestSeconds: record.avgRestSecondsPerDay,
          alertsCount: record.alertsCount,
          apps: record.topApps,
          days: record.days,
          db: db,
        ),
      ),
    );
  }

  static void showMonthly({
    required BuildContext context,
    required MonthlyHistoryRecord record,
    required AppDatabase db,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeriodDetailsScreen(
          title: record.title,
          subtitle: record.subdate,
          totalPhoneSeconds: record.totalPhoneSeconds,
          totalRestSeconds: record.totalRestSeconds,
          avgPhoneSeconds: record.avgPhoneSecondsPerDay,
          avgRestSeconds: record.avgRestSecondsPerDay,
          alertsCount: record.alertsCount,
          apps: record.topApps,
          weeks: record.weeks,
          days: record.days,
          monthDate: record.monthStart,
          db: db,
        ),
      ),
    );
  }

  @override
  State<PeriodDetailsScreen> createState() => _PeriodDetailsScreenState();
}

class _PeriodDetailsScreenState extends State<PeriodDetailsScreen> {
  String? _selectedAppPackage;
  DailyHistoryRecord? _selectedDay;

  @override
  void initState() {
    super.initState();
    if (widget.days != null && widget.days!.isNotEmpty) {
      _selectedDay = widget.days!.first;
    }
    _syncPeriodDaysIfNeeded();
  }

  Future<void> _syncPeriodDaysIfNeeded() async {
    try {
      final hasPerm = await SystemScreenTimeService.hasUsagePermission();
      if (!hasPerm) return;

      final installDateStr = widget.db.getInstallDate();
      final installDateTime = DateTime.tryParse(installDateStr) ?? DateTime.now();
      final installStart = DateTime(installDateTime.year, installDateTime.month, installDateTime.day);

      bool anyUpdated = false;
      final days = widget.days ?? [];
      for (final d in days) {
        if (d.date.isBefore(installStart)) continue;
        if (d.phoneSeconds == 0) {
          final res = await SystemScreenTimeService.getScreenAndRestBlocks(
            date: d.date,
          );
          if (res.blocks.isNotEmpty) {
            widget.db.replaceBlocksForDate(d.date, res.blocks);
            anyUpdated = true;
          }
        }
      }

      if (anyUpdated && mounted) {
        setState(() {
          if (_selectedDay != null) {
            _selectedDay = _getDayRecord(_selectedDay!.date);
          }
        });
      }
    } catch (_) {}
  }

  String get _selectedAppName {
    if (_selectedAppPackage == null) return 'All Apps';
    for (final app in widget.apps) {
      if (app.package == _selectedAppPackage ||
          app.name == _selectedAppPackage) {
        return app.name as String;
      }
    }
    return 'App';
  }

  DailyHistoryRecord _getDayRecord(DateTime dt) {
    DailyHistoryRecord? match;
    if (widget.days != null) {
      for (final d in widget.days!) {
        if (d.date.year == dt.year &&
            d.date.month == dt.month &&
            d.date.day == dt.day) {
          match = d;
          break;
        }
      }
    }

    if (match != null && match.phoneSeconds > 0) {
      return match;
    }

    // Check if SQLite database has synced activity blocks for this day
    final blocks = widget.db.getActivityBlocksForDate(dt);
    if (blocks.isNotEmpty) {
      int phoneSec = 0;
      int restSec = 0;
      final Map<String, AppUsageSnippet> dayAppMap = {};
      for (final b in blocks) {
        if (b.isActiveScreen) {
          phoneSec += b.durationSeconds;
          for (final app in b.topApps) {
            final lowerName = app.name.toLowerCase().trim();
            if (lowerName == 'home screen' ||
                lowerName == 'screen active' ||
                lowerName.isEmpty) {
              continue;
            }
            final existing = dayAppMap[app.name];
            if (existing != null) {
              dayAppMap[app.name] = AppUsageSnippet(
                name: app.name,
                package: app.package.isNotEmpty
                    ? app.package
                    : existing.package,
                seconds: existing.seconds + app.seconds,
              );
            } else {
              dayAppMap[app.name] = app;
            }
          }
        } else {
          restSec += b.durationSeconds;
        }
      }

      final topApps = dayAppMap.values.toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));
      final alerts = widget.db.getGentleRemindersCountForDate(dt);

      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final title = match?.title ?? weekdays[dt.weekday - 1];
      final subdate = match?.subdate ?? '${_getMonthAbbr(dt.month)} ${dt.day}';

      return DailyHistoryRecord(
        dateStr: DailyHistoryHelper.formatIsoDate(dt),
        date: dt,
        title: title,
        subdate: subdate,
        phoneSeconds: phoneSec,
        restSeconds: restSec,
        alertsCount: alerts,
        topApps: topApps,
      );
    }

    if (match != null) return match;

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final wName = weekdays[dt.weekday - 1];
    return DailyHistoryRecord(
      dateStr: DailyHistoryHelper.formatIsoDate(dt),
      date: dt,
      title: wName,
      subdate: '${_getMonthAbbr(dt.month)} ${dt.day}',
      phoneSeconds: 0,
      restSeconds: 0,
      alertsCount: 0,
    );
  }

  String _getMonthAbbr(int month) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return m[(month - 1).clamp(0, 11)];
  }

  int _getAppSecondsForDay(DailyHistoryRecord day, String? package) {
    if (package == null) return day.phoneSeconds;
    for (final app in day.topApps) {
      if (app.package == package ||
          (app.package.isEmpty && app.name == package)) {
        return app.seconds;
      }
    }
    return 0;
  }

  int _getMaxSecondsInPeriod(
    List<DailyHistoryRecord> allDays,
    String? package,
  ) {
    int maxSec = 0;
    for (final d in allDays) {
      final s = _getAppSecondsForDay(d, package);
      if (s > maxSec) maxSec = s;
    }
    if (package != null) {
      return maxSec > 1800 ? maxSec : 1800; // at least 30m scale for apps
    }
    return maxSec > 14400 ? maxSec : 14400; // at least 4h scale for total phone
  }

  double _getFillRatio(int seconds, int maxSeconds) {
    if (seconds <= 0 || maxSeconds <= 0) return 0.0;
    return (seconds / maxSeconds).clamp(0.06, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blueColor = AppColors.getRhythmBlue(isDark);
    final mintColor = AppColors.getRhythmGreen(isDark);
    final amberColor = AppColors.getRhythmAmber(isDark);
    final maxAppSec = widget.apps.isNotEmpty
        ? widget.apps.first.seconds as int
        : 1;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D111A) : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.textCharcoal,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: AppTextStyles.subheading.copyWith(
            color: isDark ? Colors.white : AppColors.textCharcoal,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Subtitle date range
            Center(
              child: Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Totals & Averages Box
            _buildTotalsBox(isDark),
            const SizedBox(height: 18),

            // 2. App Filter Pills
            _buildAppFilterPills(isDark, blueColor),
            const SizedBox(height: 16),

            // 3. The Capsule Board (Weekly 7-Day Glasses or Monthly Calendar Grid)
            if (widget.monthDate != null)
              _buildMonthlyCapsuleBoard(
                isDark,
                blueColor,
                mintColor,
                amberColor,
              )
            else
              _buildWeeklyCapsuleBoard(
                isDark,
                blueColor,
                mintColor,
                amberColor,
              ),
            const SizedBox(height: 14),

            // 4. Day Spotlight Card (for the tapped day)
            if (_selectedDay != null) ...[
              _buildDaySpotlightCard(
                _selectedDay!,
                isDark,
                blueColor,
                mintColor,
                amberColor,
              ),
              const SizedBox(height: 22),
            ],

            // 5. App Used Hours
            if (widget.apps.isNotEmpty) ...[
              _buildSectionHeader('App Used Hours', isDark),
              const SizedBox(height: 8),
              _buildAppUsageCard(isDark, maxAppSec, blueColor),
              const SizedBox(height: 22),
            ],

            // 6. Weekly Summary Breakdown (if Monthly)
            if (widget.weeks != null && widget.weeks!.isNotEmpty) ...[
              _buildSectionHeader('Weekly Summary Breakdown', isDark),
              const SizedBox(height: 8),
              _buildWeeksList(context, isDark),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  // --- 1. TOTALS & AVERAGES BOX ---
  Widget _buildTotalsBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D2B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          // Phone Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 13,
                      color: Colors.blue[300],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TOTAL PHONE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DailyHistoryHelper.formatScreenTime(widget.totalPhoneSeconds),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: Colors.blue[300],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${DailyHistoryHelper.formatScreenTime(widget.avgPhoneSeconds)} / day',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          const SizedBox(width: 16),
          // Rest Total
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.spa_rounded, size: 13, color: Colors.green[300]),
                    const SizedBox(width: 4),
                    Text(
                      'TOTAL REST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DailyHistoryHelper.formatScreenTime(widget.totalRestSeconds),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: Colors.green[300],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg ${DailyHistoryHelper.formatScreenTime(widget.avgRestSeconds)} / day',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. APP FILTER PILLS ---
  Widget _buildAppFilterPills(bool isDark, Color blueColor) {
    if (widget.apps.isEmpty) return const SizedBox.shrink();
    final topApps = widget.apps.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Filter Glasses By App', isDark),
            if (_selectedAppPackage != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAppPackage = null);
                },
                child: Text(
                  'Reset to All Apps',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: blueColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // All Apps Pill
              _buildFilterPill(
                label: 'All Apps',
                isSelected: _selectedAppPackage == null,
                isDark: isDark,
                blueColor: blueColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAppPackage = null);
                },
              ),
              const SizedBox(width: 8),
              // App Pills
              for (final app in topApps) ...[
                _buildFilterPill(
                  label: app.name as String,
                  packageName: app.package as String,
                  duration: app.formattedDuration as String,
                  isSelected: _selectedAppPackage == app.package,
                  isDark: isDark,
                  blueColor: blueColor,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_selectedAppPackage == app.package) {
                        _selectedAppPackage = null;
                      } else {
                        _selectedAppPackage = app.package as String;
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    String? packageName,
    String? duration,
    required bool isSelected,
    required bool isDark,
    required Color blueColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? blueColor.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark ? const Color(0xFF161D2B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? blueColor
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (packageName != null) ...[
              AppIconBadge(packageName: packageName, appName: label, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : blueColor)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            if (duration != null) ...[
              const SizedBox(width: 5),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: isSelected
                      ? (isDark ? Colors.white70 : blueColor)
                      : (isDark ? Colors.white38 : Colors.black45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 3A. WEEKLY 7-DAY CAPSULE BOARD ---
  Widget _buildWeeklyCapsuleBoard(
    bool isDark,
    Color blueColor,
    Color mintColor,
    Color amberColor,
  ) {
    final allDays = widget.days ?? [];
    final maxSeconds = _getMaxSecondsInPeriod(allDays, _selectedAppPackage);

    DateTime startMonday;
    if (allDays.isNotEmpty) {
      final d0 = allDays.first.date;
      startMonday = d0.subtract(Duration(days: d0.weekday - 1));
    } else {
      final now = DateTime.now();
      startMonday = now.subtract(Duration(days: now.weekday - 1));
    }

    const weekdaysAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCapsuleBoard : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedAppPackage == null
                    ? '7-DAY WATER GLASSES'
                    : '$_selectedAppName · 7-DAY GLASSES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendDot(blueColor, 'Screen'),
                  const SizedBox(width: 8),
                  if (_selectedAppPackage == null) ...[
                    _buildLegendDot(mintColor, 'Rest'),
                    const SizedBox(width: 8),
                  ],
                  _buildLegendDot(amberColor, 'Alert'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7 Glasses Row
          Row(
            children: [
              for (int i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _buildDayGlassItem(
                    dayDate: startMonday.add(Duration(days: i)),
                    weekdayName: weekdaysAbbr[i],
                    isDark: isDark,
                    blueColor: blueColor,
                    mintColor: mintColor,
                    amberColor: amberColor,
                    maxSeconds: maxSeconds,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayGlassItem({
    required DateTime dayDate,
    required String weekdayName,
    required bool isDark,
    required Color blueColor,
    required Color mintColor,
    required Color amberColor,
    required int maxSeconds,
  }) {
    final dayRecord = _getDayRecord(dayDate);
    final appSeconds = _getAppSecondsForDay(dayRecord, _selectedAppPackage);
    final fillRatio = _getFillRatio(appSeconds, maxSeconds);
    final isSelected =
        _selectedDay?.date.year == dayDate.year &&
        _selectedDay?.date.month == dayDate.month &&
        _selectedDay?.date.day == dayDate.day;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDay = dayRecord);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          // Weekday label
          Text(
            weekdayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? blueColor
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${dayDate.day}',
            style: TextStyle(
              fontSize: 9.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? blueColor
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
          const SizedBox(height: 6),

          // The Glass Capsule
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 70,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: isSelected ? 0.08 : 0.03,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? blueColor
                    : (isDark ? Colors.white12 : Colors.black12),
                width: isSelected ? 2.0 : 0.8,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: blueColor.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Blue water fill
                  FractionallySizedBox(
                    heightFactor: fillRatio,
                    widthFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: blueColor.withValues(
                          alpha: isDark ? 0.85 : 0.75,
                        ),
                      ),
                    ),
                  ),
                  // Mint rest cap (only if All Apps and rest > 0)
                  if (_selectedAppPackage == null &&
                      fillRatio > 0 &&
                      dayRecord.restSeconds > 0)
                    Positioned(
                      bottom: (fillRatio * 70) - 3.5,
                      left: 0,
                      right: 0,
                      child: Container(height: 3.5, color: mintColor),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Formatted duration text
          Text(
            appSeconds > 0
                ? DailyHistoryHelper.formatScreenTime(appSeconds)
                : '0m',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),

          // Alert indicator
          if (dayRecord.alertsCount > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  size: 9,
                  color: amberColor,
                ),
                const SizedBox(width: 1),
                Text(
                  '${dayRecord.alertsCount}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: amberColor,
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- 3B. MONTHLY CALENDAR GRID (OPTION B: 4–5 ROWS × 7 COLS) ---
  Widget _buildMonthlyCapsuleBoard(
    bool isDark,
    Color blueColor,
    Color mintColor,
    Color amberColor,
  ) {
    final allDays = widget.days ?? [];
    final maxSeconds = _getMaxSecondsInPeriod(allDays, _selectedAppPackage);

    final monthDate =
        widget.monthDate ??
        (allDays.isNotEmpty ? allDays.first.date : DateTime.now());
    final year = monthDate.year;
    final month = monthDate.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDay = DateTime(year, month, 1);
    final startOffset = firstDay.weekday - 1; // 0 for Mon, 6 for Sun
    final totalCells = startOffset + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    final monthName = _getFullMonthName(month);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCapsuleBoard : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedAppPackage == null
                    ? '$monthName CALENDAR BOARD'
                    : '$_selectedAppName · $monthName',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendDot(blueColor, 'Screen'),
                  const SizedBox(width: 8),
                  _buildLegendDot(amberColor, 'Alert'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Days of week header
          Row(
            children: const [
              Expanded(
                child: Center(child: Text('M', style: _calHeaderStyle)),
              ),
              Expanded(
                child: Center(child: Text('T', style: _calHeaderStyle)),
              ),
              Expanded(
                child: Center(child: Text('W', style: _calHeaderStyle)),
              ),
              Expanded(
                child: Center(child: Text('T', style: _calHeaderStyle)),
              ),
              Expanded(
                child: Center(child: Text('F', style: _calHeaderStyle)),
              ),
              Expanded(
                child: Center(child: Text('S', style: _calHeaderStyle)),
              ),
              Expanded(
                child: Center(child: Text('S', style: _calHeaderStyle)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // The Calendar Grid
          for (int r = 0; r < totalRows; r++) ...[
            if (r > 0) const SizedBox(height: 6),
            Row(
              children: [
                for (int c = 0; c < 7; c++) ...[
                  if (c > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _buildMonthCalendarCell(
                      rowIndex: r,
                      colIndex: c,
                      startOffset: startOffset,
                      daysInMonth: daysInMonth,
                      year: year,
                      month: month,
                      isDark: isDark,
                      blueColor: blueColor,
                      mintColor: mintColor,
                      amberColor: amberColor,
                      maxSeconds: maxSeconds,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static const TextStyle _calHeaderStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Colors.grey,
  );

  Widget _buildMonthCalendarCell({
    required int rowIndex,
    required int colIndex,
    required int startOffset,
    required int daysInMonth,
    required int year,
    required int month,
    required bool isDark,
    required Color blueColor,
    required Color mintColor,
    required Color amberColor,
    required int maxSeconds,
  }) {
    final cellIndex = rowIndex * 7 + colIndex;
    final dayNum = cellIndex - startOffset + 1;

    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox(height: 52);
    }

    final cellDate = DateTime(year, month, dayNum);
    final dayRecord = _getDayRecord(cellDate);
    final appSeconds = _getAppSecondsForDay(dayRecord, _selectedAppPackage);
    final fillRatio = _getFillRatio(appSeconds, maxSeconds);
    final isSelected =
        _selectedDay?.date.year == year &&
        _selectedDay?.date.month == month &&
        _selectedDay?.date.day == dayNum;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDay = dayRecord);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isSelected ? 0.09 : 0.03,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? blueColor
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.8 : 0.6,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: blueColor.withValues(alpha: 0.22),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Blue water fill
              FractionallySizedBox(
                heightFactor: fillRatio,
                widthFactor: 1.0,
                child: Container(
                  color: blueColor.withValues(alpha: isDark ? 0.85 : 0.75),
                ),
              ),
              // Day number at top
              Positioned(
                top: 3,
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : blueColor)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              // Alert dot at bottom
              if (dayRecord.alertsCount > 0)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: amberColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFullMonthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  // --- 4. DAY SPOTLIGHT CARD ---
  Widget _buildDaySpotlightCard(
    DailyHistoryRecord day,
    bool isDark,
    Color blueColor,
    Color mintColor,
    Color amberColor,
  ) {
    final top3 = day.topApps.take(3).toList();
    final todayStr = DailyHistoryHelper.formatIsoDate(DateTime.now());
    final yesterdayStr = DailyHistoryHelper.formatIsoDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D2B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date + Alert pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: blueColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${day.title} · ${day.subdate}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (day.alertsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: amberColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 11,
                        color: amberColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${day.alertsCount} ${day.alertsCount == 1 ? "alert" : "alerts"}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: amberColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '0 alerts',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Two-column Phone vs Rest
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '📱 Screen: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      DailyHistoryHelper.formatScreenTime(day.phoneSeconds),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: Colors.blue[300],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '🌿 Rest: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      DailyHistoryHelper.formatScreenTime(day.restSeconds),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: Colors.green[300],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // If app filter is active, show that app's specific time on this day
          if (_selectedAppPackage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: blueColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  AppIconBadge(
                    packageName: _selectedAppPackage!,
                    appName: _selectedAppName,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedAppName on this day:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DailyHistoryHelper.formatScreenTime(
                      _getAppSecondsForDay(day, _selectedAppPackage),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: blueColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Top 3 apps on this day
          if (top3.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < top3.length; i++) ...[
              if (i > 0) const SizedBox(height: 5),
              Row(
                children: [
                  AppIconBadge(
                    packageName: top3[i].package,
                    appName: top3[i].name,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      top3[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    DailyHistoryHelper.formatScreenTime(top3[i].seconds),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ],

          const SizedBox(height: 12),

          // Open Full Storyboard Action Button
          InkWell(
            onTap: () async {
              await DayRhythmDetailSheet.show(
                context: context,
                db: widget.db,
                date: day.date,
                dateTitle: DailyHistoryHelper.formatDateTitle(
                  day.dateStr,
                  todayStr,
                  yesterdayStr,
                ),
                dateSubtitle: day.subdate,
                screenTimeSeconds: day.phoneSeconds,
              );
              if (mounted) {
                setState(() {
                  _selectedDay = _getDayRecord(day.date);
                });
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open ${day.subdate} 24h Storyboard',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: blueColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: blueColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. APP USAGE CARD ---
  Widget _buildAppUsageCard(bool isDark, int maxAppSec, Color blueColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161D2B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12,
        ),
      ),
      child: Column(
        children: widget.apps.map<Widget>((app) {
          final isSelected = _selectedAppPackage == app.package;
          final pct = (app.seconds / (maxAppSec > 0 ? maxAppSec : 1)).clamp(
            0.05,
            1.0,
          );

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (_selectedAppPackage == app.package) {
                  _selectedAppPackage = null;
                } else {
                  _selectedAppPackage = app.package as String;
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  AppIconBadge(
                    packageName: app.package as String,
                    appName: app.name as String,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              app.name as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? blueColor
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            Text(
                              app.formattedDuration as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? blueColor
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isSelected ? blueColor : AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 6. WEEKS LIST (FOR MONTHLY SUMMARY) ---
  Widget _buildWeeksList(BuildContext context, bool isDark) {
    return Column(
      children: widget.weeks!.map((w) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161D2B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black12,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${w.title} (${w.dateRangeStr})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '📱 ${DailyHistoryHelper.formatScreenTime(w.totalPhoneSeconds)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.blue[300],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '🌿 ${DailyHistoryHelper.formatScreenTime(w.totalRestSeconds)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.green[300],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '🔔 ${w.alertsCount} ${w.alertsCount == 1 ? "alert" : "alerts"}',
                style: TextStyle(
                  fontSize: 11,
                  color: w.alertsCount > 0
                      ? AppColors.getRhythmAmber(isDark)
                      : (isDark ? Colors.white38 : Colors.black45),
                ),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              PeriodDetailsScreen.showWeekly(
                context: context,
                record: w,
                db: widget.db,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: isDark ? Colors.white38 : Colors.black45,
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
