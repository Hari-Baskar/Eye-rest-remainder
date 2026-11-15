import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/system_screen_time_service.dart';
import '../../../eye_rest/presentation/widgets/day_rhythm_detail_sheet.dart';
import '../../../eye_rest/presentation/widgets/app_icon_badge.dart';
import '../../domain/entities/history_records.dart';
import '../widgets/daily_history_tile.dart';
import 'period_details_screen.dart';

/// HistoryScreen
///
/// Clean, unopinionated history screen designed from the user's perspective:
/// - Three tabs: [ Daily ] [ Weekly ] [ Monthly ]
/// - Direct list of clean, informative tiles (no duplicate summary cards, no gamification/points).
/// - Prominently highlights Phone Used, Eye Rest, and Longest Non-Stop Strain.
/// - Shows explanatory info dialog when tapping the (i) icon on the strain pill.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _syncRecentDays();
  }

  Future<void> _syncRecentDays() async {
    try {
      final hasPerm = await SystemScreenTimeService.hasUsagePermission();
      if (!hasPerm) return;

      final db = ref.read(databaseProvider);
      final rhythm = ref.read(dailyRhythmProvider);
      final installDateStr = db.getInstallDate();
      final installDateTime = DateTime.tryParse(installDateStr) ?? DateTime.now();
      final installStart = DateTime(installDateTime.year, installDateTime.month, installDateTime.day);
      final now = DateTime.now();
      bool anyUpdated = false;

      // Only sync back to the day the app was installed!
      final daysSinceInstall = now.difference(installStart).inDays;
      final daysToSync = (daysSinceInstall + 1).clamp(1, 31);
      for (int i = 0; i < daysToSync; i++) {
        final targetDate = now.subtract(Duration(days: i));
        final res = await SystemScreenTimeService.getScreenAndRestBlocks(
          date: targetDate,
          requiredRestSeconds: rhythm.requiredRestSeconds,
        );
        if (res.blocks.isNotEmpty) {
          db.replaceBlocksForDate(targetDate, res.blocks);
          anyUpdated = true;
          if (i == 1 && mounted) {
            setState(() {});
          }
        }
      }

      if (anyUpdated && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showStrainInfoDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardSurface : AppColors.cardSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: AppColors.strainRed,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About Longest Strain',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textCharcoal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'This measures your single longest continuous screen stretch before taking a real eye rest (at least 30 seconds).',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Switching between apps or locking your phone for just a few seconds does not break this stretch, giving you an honest look at your peak eye strain.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final dailyRhythm = ref.watch(dailyRhythmProvider);

    final historyData = HistoryAggregator.buildHistory(
      db: db,
      currentRhythm: dailyRhythm,
    );

    final dailyList = historyData['daily'] as List<DailyHistoryRecord>;
    final weeklyList = historyData['weekly'] as List<WeeklyHistoryRecord>;
    final monthlyList = historyData['monthly'] as List<MonthlyHistoryRecord>;

    return Scaffold(
      backgroundColor: isDark ? AppColors.pitchDarkBackground : AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textCharcoal,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'History',
          style: AppTextStyles.subheading.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? AppColors.darkCardSurface : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                unselectedLabelColor: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Daily'),
                  Tab(text: 'Weekly'),
                  Tab(text: 'Monthly'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // 1. Daily Tab
            _buildDailyTab(dailyList, isDark, db),

            // 2. Weekly Tab
            _buildWeeklyTab(weeklyList, isDark, db),

            // 3. Monthly Tab
            _buildMonthlyTab(monthlyList, isDark, db),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: DAILY ---
  Widget _buildDailyTab(
    List<DailyHistoryRecord> list,
    bool isDark,
    AppDatabase db,
  ) {
    if (list.isEmpty) {
      return _buildEmptyState('No daily records yet', isDark);
    }

    final todayStr = DailyHistoryHelper.formatIsoDate(DateTime.now());
    final yesterdayStr = DailyHistoryHelper.formatIsoDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    return RefreshIndicator(
      onRefresh: _syncRecentDays,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        itemCount: list.length,
        itemBuilder: (context, index) {
        final item = list[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardSurface : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              DayRhythmDetailSheet.show(
                context: context,
                db: db,
                date: item.date,
                dateTitle: DailyHistoryHelper.formatDateTitle(
                  item.dateStr,
                  todayStr,
                  yesterdayStr,
                ),
                dateSubtitle: item.subdate,
                screenTimeSeconds: item.phoneSeconds,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.subdate,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Compact Single Row: Active • Rest • Alerts
                  _buildCompactMetricsRow(
                    phoneVal: DailyHistoryHelper.formatScreenTime(item.phoneSeconds),
                    restVal: DailyHistoryHelper.formatScreenTime(item.restSeconds),
                    alertsCount: item.alertsCount,
                    isDark: isDark,
                  ),

                  if (item.topApps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                    ),
                    const SizedBox(height: 9),

                    // Apps used in vertical stack (icon on top, duration below)
                    _buildCompactHorizontalApps(item.topApps, isDark),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  // --- TAB 2: WEEKLY ---
  Widget _buildWeeklyTab(
    List<WeeklyHistoryRecord> list,
    bool isDark,
    AppDatabase db,
  ) {
    if (list.isEmpty) {
      return _buildEmptyState('No weekly records yet', isDark);
    }

    return RefreshIndicator(
      onRefresh: _syncRecentDays,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        itemCount: list.length,
        itemBuilder: (context, index) {
        final item = list[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardSurface : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              PeriodDetailsScreen.showWeekly(
                context: context,
                record: item,
                db: db,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.dateRangeStr,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Compact Single Row: Active • Rest • Alerts
                  _buildCompactMetricsRow(
                    phoneVal: DailyHistoryHelper.formatScreenTime(item.totalPhoneSeconds),
                    restVal: DailyHistoryHelper.formatScreenTime(item.totalRestSeconds),
                    alertsCount: item.alertsCount,
                    isDark: isDark,
                  ),

                  if (item.topApps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                    ),
                    const SizedBox(height: 9),

                    // Apps used in vertical stack (icon on top, duration below)
                    _buildCompactHorizontalApps(item.topApps, isDark),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  // --- TAB 3: MONTHLY ---
  Widget _buildMonthlyTab(
    List<MonthlyHistoryRecord> list,
    bool isDark,
    AppDatabase db,
  ) {
    if (list.isEmpty) {
      return _buildEmptyState('No monthly records yet', isDark);
    }

    return RefreshIndicator(
      onRefresh: _syncRecentDays,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        itemCount: list.length,
        itemBuilder: (context, index) {
        final item = list[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardSurface : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              PeriodDetailsScreen.showMonthly(
                context: context,
                record: item,
                db: db,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.subdate,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Compact Single Row: Active • Rest • Alerts
                  _buildCompactMetricsRow(
                    phoneVal: DailyHistoryHelper.formatScreenTime(item.totalPhoneSeconds),
                    restVal: DailyHistoryHelper.formatScreenTime(item.totalRestSeconds),
                    alertsCount: item.alertsCount,
                    isDark: isDark,
                  ),

                  if (item.topApps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                    ),
                    const SizedBox(height: 9),

                    // Apps used in vertical stack (icon on top, duration below)
                    _buildCompactHorizontalApps(item.topApps, isDark),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  // --- Reusable Metric Components ---
  Widget _buildCompactMetricsRow({
    required String phoneVal,
    required String restVal,
    required int alertsCount,
    required bool isDark,
  }) {
    final dividerColor = isDark ? AppColors.darkBorder : AppColors.borderLight;
    final slateBlue = AppColors.getRhythmBlue(isDark);
    final restGreen = AppColors.getRhythmGreen(isDark);
    final alertAmber = AppColors.getRhythmAmber(isDark);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Active screen
        Expanded(
          child: _buildMetricItem(
            value: phoneVal,
            label: 'Active',
            dotColor: slateBlue,
            isDark: isDark,
          ),
        ),
        Container(width: 1, height: 26, color: dividerColor),
        // 2. Phone rest
        Expanded(
          child: _buildMetricItem(
            value: restVal,
            label: 'Rest',
            dotColor: restGreen,
            isDark: isDark,
          ),
        ),
        Container(width: 1, height: 26, color: dividerColor),
        // 3. Alerts
        Expanded(
          child: _buildMetricItem(
            value: '$alertsCount',
            label: alertsCount == 1 ? 'Alert' : 'Alerts',
            dotColor: alertsCount > 0
                ? alertAmber
                : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String value,
    required String label,
    required Color dotColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: isDark ? AppColors.darkTextPrimary : AppColors.textCharcoal,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactHorizontalApps(
    List<AppUsageSnippet> apps,
    bool isDark,
  ) {
    if (apps.isEmpty) {
      return const SizedBox.shrink();
    }

    // Top 3 apps matched directly with the 3-column split of the metrics row
    final topApps = apps.take(3).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0)
            const SizedBox(width: 1), // Invisible spacer matching the 1px divider in the top section
          Expanded(
            child: i < topApps.length
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AppIconBadge(
                        packageName: topApps[i].package,
                        appName: topApps[i].name,
                        size: 34,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatAppTime(topApps[i].seconds),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textSlateNavy,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  String _formatAppTime(int sec) {
    if (sec <= 0) return '0s';
    if (sec < 60) return '${sec}s';
    return DailyHistoryHelper.formatScreenTime(sec);
  }

  Widget _buildStrainPill({
    required BuildContext context,
    String prefix = 'Longest non-stop:',
    required String strainSummary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.strainRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.strainRed.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 14,
            color: AppColors.strainRed,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.strainRedLight : AppColors.strainRedDark,
                ),
                children: [
                  TextSpan(
                    text: '$prefix ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: strainSummary,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showStrainInfoDialog(context, isDark),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
