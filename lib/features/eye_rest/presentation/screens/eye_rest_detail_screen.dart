import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reset/features/eye_rest/domain/usecases/daily_rhythm_helper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/system_screen_time_service.dart';
import '../../../progress/presentation/widgets/daily_history_tile.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

import '../widgets/alert_highlights_section.dart';
import '../widgets/cumulative_app_usage_section.dart';
import '../widgets/hourly_water_chips_storyboard.dart';

/// EyeRestDetailScreen (Cardless Storyboard & Custom Durations)
///
/// Pure surface design without any card boxes or container borders:
/// - Hero circular activity ring with cumulative continuous time (20m -> 40m).
/// - Flat 3-column summary metrics directly on the surface (Active screen, Phone rest, Timer Respect).
/// - Storyboard Rhythm Bar with dynamic peaks and tap inspector.
/// - Custom Continuous Screen Duration picker (presets + custom minutes).
/// - Custom Required Rest Duration picker (presets + custom seconds/minutes).
/// - Flat Smart Gaming Defense switch and transparent explanations.
class EyeRestDetailScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAllHistory;
  final ThemeMode? currentThemeMode;
  final Function(ThemeMode mode)? onThemeChanged;
  final DateTime? initialDate;

  const EyeRestDetailScreen({
    super.key,
    this.onOpenSettings,
    this.onOpenAllHistory,
    this.currentThemeMode,
    this.onThemeChanged,
    this.initialDate,
  });

  @override
  ConsumerState<EyeRestDetailScreen> createState() =>
      _EyeRestDetailScreenState();
}

class _EyeRestDetailScreenState extends ConsumerState<EyeRestDetailScreen>
    with WidgetsBindingObserver {
  late DateTime _currentDate;
  DailyRhythmEntity? _historicalRhythm;
  bool _isLoadingDate = false;
  String? _selectedAppPackage;
  int? _selectedStoryboardHour;
  int _selectedMetricTab =
      0; // 0: Active screen (24-Hour Rhythm), 1: Phone rest (24-Hour Rhythm), 2: Alerts (Alert Moments)
  final GlobalKey _storyboardKey = GlobalKey();
  bool _hasUsagePermission = true;

  bool get _isToday {
    final now = DateTime.now();
    return _currentDate.year == now.year &&
        _currentDate.month == now.month &&
        _currentDate.day == now.day;
  }

  bool get _isYesterday {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return _currentDate.year == yest.year &&
        _currentDate.month == yest.month &&
        _currentDate.day == yest.day;
  }

  String get _formattedDateBadge {
    const months = [
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
    final mStr = months[_currentDate.month - 1];
    if (_isToday) return 'Today, $mStr ${_currentDate.day}';
    if (_isYesterday) return 'Yesterday, $mStr ${_currentDate.day}';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[_currentDate.weekday - 1]}, $mStr ${_currentDate.day}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentDate = widget.initialDate ?? DateTime.now();
    _checkPermission();
    if (!_isToday) {
      _loadDateRhythm(_currentDate);
    }
  }

  Future<void> _loadDateRhythm(DateTime date) async {
    final now = DateTime.now();
    final isCur =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (isCur) {
      if (mounted) {
        setState(() {
          _currentDate = date;
          _historicalRhythm = null;
          _isLoadingDate = false;
        });
      }
      return;
    }

    setState(() {
      _currentDate = date;
      _isLoadingDate = true;
    });

    try {
      final db = ref.read(databaseProvider);
      final liveRhythm = ref.read(dailyRhythmProvider);
      final r = await DailyRhythmHelper.syncAndGetRhythmForDate(
        db: db,
        date: date,
        requiredRestSeconds: liveRhythm.requiredRestSeconds,
      );
      if (mounted) {
        setState(() {
          _historicalRhythm = r;
          _isLoadingDate = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDate = false);
    }
  }

  void _navigateDay(int offset) {
    final newDate = _currentDate.add(Duration(days: offset));
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (newDate.isAfter(todayEnd)) return;

    final db = ref.read(databaseProvider);
    final installDateStr = db.getInstallDate();
    final newDateStr = DailyHistoryHelper.formatIsoDate(newDate);
    if (newDateStr.compareTo(installDateStr) < 0) return;

    _loadDateRhythm(newDate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await SystemScreenTimeService.hasUsagePermission();
    if (mounted) {
      setState(() => _hasUsagePermission = granted);
      if (granted) {
        ref.read(dailyRhythmProvider.notifier).syncWithSystemUsage();
      }
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SettingsScreen(
          currentThemeMode: widget.currentThemeMode ?? ThemeMode.system,
          onThemeChanged: widget.onThemeChanged ?? (_) {},
        ),
      ),
    );
  }

  void _jumpToStoryboardHour(int hour) {
    setState(() {
      _selectedMetricTab = 0;
      _selectedStoryboardHour = hour;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_storyboardKey.currentContext != null) {
        Scrollable.ensureVisible(
          _storyboardKey.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  String _getBreakStatusText(DailyRhythmEntity rhythm) {
    if (!rhythm.isScreenOn) {
      return 'Screen off • Eyes rested';
    }
    if (rhythm.isGentleReminderActive) {
      return 'Take a 20s break';
    }
    final target = rhythm.cycleTargetSeconds > 0
        ? rhythm.cycleTargetSeconds
        : 1200;
    final current = rhythm.safeSessionSeconds % target;
    final remSec = target - current;
    if (remSec < 60) {
      return 'Next break in ${remSec}s';
    }
    final remM = (remSec / 60).ceil();
    return 'Next break in $remM min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final greenColor = AppColors.getRhythmGreen(isDark);
    final slateColor = AppColors.getRhythmSlate(isDark);
    final blueColor = AppColors.getRhythmBlue(isDark);
    final amberColor = AppColors.getRhythmAmber(isDark);

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    final liveRhythm = ref.watch(dailyRhythmProvider);
    final rhythm = (_isToday || _historicalRhythm == null)
        ? liveRhythm
        : _historicalRhythm!;

    final isScreenOn = _isToday ? rhythm.isScreenOn : false;
    final isBreakActive =
        _isToday && isScreenOn && rhythm.isGentleReminderActive;
    final activeColor = isScreenOn
        ? (isBreakActive ? amberColor : slateColor)
        : greenColor;

    final targetMins = rhythm.cycleTargetSeconds ~/ 60;
    final now = DateTime.now();
    final todayStr = DailyHistoryHelper.formatIsoDate(now);

    final db = ref.read(databaseProvider);
    final installDateStr = db.getInstallDate();
    final currentDateStr = DailyHistoryHelper.formatIsoDate(_currentDate);
    final canGoBack = currentDateStr.compareTo(installDateStr) > 0;
    final canGoForward = !_isToday;

    return Scaffold(
      backgroundColor: isDark ? AppColors.pitchDarkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: widget.initialDate != null,
        leading: widget.initialDate != null
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : AppColors.textCharcoal,
                  size: 22,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : (widget.onOpenSettings != null
                  ? IconButton(
                      icon: Icon(
                        Icons.menu_rounded,
                        color: isDark ? Colors.white : AppColors.textCharcoal,
                        size: 22,
                      ),
                      onPressed: widget.onOpenSettings,
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : AppColors.textCharcoal,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                    )),
        title: widget.initialDate != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 24,
                      color: canGoBack
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                    onPressed: canGoBack ? () => _navigateDay(-1) : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Previous day',
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.06,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formattedDateBadge,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textCharcoal,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: canGoForward
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                    onPressed: canGoForward ? () => _navigateDay(1) : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Next day',
                  ),
                ],
              )
            : (widget.onOpenSettings != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appName,
                          style: AppTextStyles.heading.copyWith(
                            color: isDark
                                ? Colors.white
                                : AppColors.textCharcoal,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          DailyHistoryHelper.formatSubtitle(
                            todayStr,
                            true,
                            false,
                          ),
                          style: AppTextStyles.small.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Eye Care & Rhythm',
                      style: AppTextStyles.subheading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textCharcoal,
                      ),
                    )),
        actions: [
          if (widget.initialDate == null && widget.onOpenAllHistory != null)
            IconButton(
              icon: Icon(
                Icons.history_rounded,
                color: isDark ? Colors.white : AppColors.textCharcoal,
                size: 22,
              ),
              onPressed: widget.onOpenAllHistory,
              tooltip: 'All History',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Activity Ring & Status (Only shown for Today - HIDDEN for past days!)
              if (_isToday) ...[
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Calm Circular Activity Ring (Tap to open Settings)
                      GestureDetector(
                        onTap: _openSettings,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 155,
                          height: 155,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background track
                              SizedBox(
                                width: 140,
                                height: 140,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 9,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                              // Progress Arc
                              SizedBox(
                                width: 140,
                                height: 140,
                                child: CircularProgressIndicator(
                                  value: rhythm.sessionProgress,
                                  strokeWidth: 9,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    activeColor,
                                  ),
                                ),
                              ),
                              // Center Text
                              Center(
                                child: Text(
                                  rhythm.sessionFormatted,
                                  style: AppTextStyles.heading.copyWith(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: isBreakActive
                                        ? amberColor
                                        : (isDark
                                              ? Colors.white
                                              : AppColors.textCharcoal),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Status Pill (Tap to open Settings)
                      GestureDetector(
                        onTap: _openSettings,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activeColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _getBreakStatusText(rhythm),
                                style: AppTextStyles.small.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: activeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                const SizedBox(height: 8),
              ],

              // 3-Metric Interactive Selector (Active screen, Phone rest, Alerts today)
              // Touching 'Active screen' or 'Phone rest' shows 24-Hour Rhythm; touching 'Alerts' shows Alert Moments
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildMetricColumn(
                      value: rhythm.activeScreenFormatted,
                      label: 'Active screen',
                      color: slateColor,
                      isDark: isDark,
                      showUnderline: false,
                      onTap: () => setState(() => _selectedMetricTab = 0),
                    ),
                  ),
                  Container(width: 1, height: 32, color: dividerColor),
                  Expanded(
                    child: _buildMetricColumn(
                      value: rhythm.phoneRestFormatted,
                      label: 'Phone rest',
                      color: greenColor,
                      isDark: isDark,
                      showUnderline: false,
                      onTap: () => setState(() => _selectedMetricTab = 1),
                    ),
                  ),
                  Container(width: 1, height: 32, color: dividerColor),
                  Expanded(
                    child: _buildMetricColumn(
                      value: '${rhythm.totalAlertsCount}',
                      label: _isToday ? 'Alerts today' : 'Alerts',
                      color: amberColor,
                      isDark: isDark,
                      showUnderline: _selectedMetricTab == 2,
                      onTap: () => setState(() => _selectedMetricTab = 2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              Divider(height: 1, thickness: 0.7, color: dividerColor),
              const SizedBox(height: 20),

              if (_isLoadingDate)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_hasUsagePermission) ...[
                if (_selectedMetricTab != 2) ...[
                  // TAB 1 & 2: 24-HOUR RHYTHM STORYBOARD (Active Screen or Phone Rest)
                  // Today's Cumulative App Usage Breakdown (Top Apps)
                  CumulativeAppUsageSection(
                    rhythm: rhythm,
                    isDark: isDark,
                    showTitle: false,
                    selectedPackage: _selectedAppPackage,
                    onAppSelected: (app) {
                      setState(() {
                        _selectedAppPackage =
                            (_selectedAppPackage == app?.package)
                            ? null
                            : app?.package;
                      });
                    },
                  ),

                  const SizedBox(height: 22),
                  Divider(height: 1, thickness: 0.7, color: dividerColor),
                  const SizedBox(height: 20),

                  // 24 Hourly Water Chips Storyboard + Selected Hour Inspection
                  KeyedSubtree(
                    key: _storyboardKey,
                    child: HourlyWaterChipsStoryboard(
                      rhythm: rhythm,
                      blocks: rhythm.blocks,
                      date: _currentDate,
                      isToday: _isToday,
                      alertTimestamps: ref
                          .read(databaseProvider)
                          .getGentleReminderTimestampsForDate(_currentDate),
                      isDark: isDark,
                      slateColor: slateColor,
                      mintColor: greenColor,
                      blueColor: blueColor,
                      amberColor: amberColor,
                      dividerColor: dividerColor,
                      selectedAppPackage: _selectedAppPackage,
                      onAppSelected: (pkg) {
                        setState(() {
                          _selectedAppPackage = pkg;
                        });
                      },
                      selectedHour: _selectedStoryboardHour,
                      onHourSelected: (h) {
                        setState(() {
                          _selectedStoryboardHour = h;
                        });
                      },
                    ),
                  ),
                ] else ...[
                  // TAB 2: ALERT MOMENTS & COMPLIANCE TABLE
                  Builder(
                    builder: (context) {
                      final dayAlerts = ref
                          .read(databaseProvider)
                          .getGentleReminderTimestampsForDate(_currentDate);
                      if (dayAlerts.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 40,
                                  color: greenColor,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No alerts triggered',
                                  style: AppTextStyles.subheading.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'All continuous screen sessions stayed under target or breaks were respected.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.small.copyWith(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return AlertHighlightsSection(
                        alertTimestamps: dayAlerts,
                        blocks: rhythm.blocks,
                        rhythm: rhythm,
                        date: _currentDate,
                        requiredRestSeconds: rhythm.requiredRestSeconds,
                        isDark: isDark,
                        onHourSelected: (h) {
                          setState(() {
                            _selectedMetricTab = 0;
                            _jumpToStoryboardHour(h);
                          });
                        },
                      );
                    },
                  ),
                ],
              ] else ...[
                // Clean & friendly Unlock Prompt (Option 1)
                _buildUsageUnlockCard(blueColor, greenColor, isDark),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn({
    required String value,
    required String label,
    required Color color,
    required bool isDark,
    bool showUnderline = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.subheading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textCharcoal,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5.5,
                height: 5.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.small.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Minimal active indicator underline (only shown for Alert column when selected)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 2.5,
            width: showUnderline ? 24 : 0,
            decoration: BoxDecoration(
              color: showUnderline ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageUnlockCard(Color blueColor, Color mintColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: blueColor.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: blueColor.withValues(alpha: isDark ? 0.22 : 0.16),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: blueColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_open_rounded, size: 24, color: blueColor),
          ),
          const SizedBox(height: 12),
          Text(
            'Unlock 24-Hour App Breakdown',
            textAlign: TextAlign.center,
            style: AppTextStyles.subheading.copyWith(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textSlateNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enable Usage Access to reveal your hourly app timeline and see exact app switch durations throughout the day.',
            textAlign: TextAlign.center,
            style: AppTextStyles.small.copyWith(
              fontSize: 12,
              height: 1.45,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          // Clean feature highlights
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildUnlockFeaturePill(
                icon: Icons.history_rounded,
                label: 'Hourly Timeline',
                color: blueColor,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildUnlockFeaturePill(
                icon: Icons.pie_chart_outline_rounded,
                label: 'App Usage Rank',
                color: mintColor,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => SystemScreenTimeService.openUsageSettings(),
            style: ElevatedButton.styleFrom(
              backgroundColor: blueColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.security_rounded, size: 16),
            label: const Text(
              'Enable in Settings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 12,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '100% on-device private • No account or data leaves phone',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockFeaturePill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
