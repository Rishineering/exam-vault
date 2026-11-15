import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
import '../data/models.dart';

/// Performance Analytics screen.
///
/// Shows overview stats, accuracy by subject, weak areas, and a 7-day
/// study time & test performance trend chart.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  double _overallAccuracy = 0.0;
  int _totalAttempts = 0;
  int _totalStudyMinutes = 0;
  Map<String, double> _accuracyBySubject = {};
  List<String> _weakAreas = [];
  List<DailyStudyStat> _dailyStats = const [];
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadMockTestAttempts();
    await state.loadMockTests();
    final overall = await state.getOverallAccuracy();
    final attempts = state.mockTestAttempts.length;
    final minutes = await state.getTotalStudyTimeMinutes();
    final bySubject = await state.getAccuracyBySubject();
    final weak = await state.getWeakAreas();
    final daily = await state.getDailyStudyStats(days: 7);

    if (!mounted) return;
    setState(() {
      _overallAccuracy = overall;
      _totalAttempts = attempts;
      _totalStudyMinutes = minutes;
      _accuracyBySubject = bySubject;
      _weakAreas = weak;
      _dailyStats = daily;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppText.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.performanceAnalytics),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overview hero card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [scheme.primary, scheme.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.overview,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                label: t.overallAccuracy,
                                value: '${_overallAccuracy.toStringAsFixed(0)}%',
                                icon: Icons.show_chart_rounded,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: t.totalAttempts,
                                value: _totalAttempts.toString(),
                                icon: Icons.assignment_rounded,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: t.studyTime,
                                value: _formatMinutes(_totalStudyMinutes, t),
                                icon: Icons.access_time_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 7-day Study Trend Chart
                  Text(
                    t.studyTimeTrend,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StudyTrendCard(
                    dailyStats: _dailyStats,
                    t: t,
                    selectedIndex: _selectedDayIndex,
                    onSelectDay: (idx) {
                      setState(() {
                        _selectedDayIndex =
                            _selectedDayIndex == idx ? null : idx;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Accuracy by Subject
                  if (_accuracyBySubject.isNotEmpty) ...[
                    Text(
                      t.accuracyBySubject,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final entry in _accuracyBySubject.entries) ...[
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(entry.key),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                              value: (entry.value / 100).clamp(0.0, 1.0),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              color: entry.value >= 60
                                  ? Colors.green
                                  : entry.value >= 40
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                          trailing: Text(
                            '${entry.value.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: entry.value >= 60
                                  ? Colors.green
                                  : entry.value >= 40
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // Weak areas
                  if (_weakAreas.isNotEmpty) ...[
                    Text(
                      t.weakAreasTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final area in _weakAreas) ...[
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            area,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            t.isHindi
                                ? 'सटीकता 50% से कम है'
                                : 'Accuracy is below 50%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }

  static String _formatMinutes(int minutes, AppText t) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '$h${t.hoursShort} $m${t.minutesShort}';
    return '$m${t.minutesShort}';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.onPrimary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// 7-day study time & accuracy chart.
class _StudyTrendCard extends StatelessWidget {
  const _StudyTrendCard({
    required this.dailyStats,
    required this.t,
    required this.selectedIndex,
    required this.onSelectDay,
  });

  final List<DailyStudyStat> dailyStats;
  final AppText t;
  final int? selectedIndex;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final totalWeekMinutes = dailyStats.fold<int>(
      0,
      (sum, s) => sum + s.studyMinutes,
    );
    final maxMinutes = dailyStats.fold<int>(
      30,
      (maxVal, s) => math.max(maxVal, s.studyMinutes),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  t.last7Days,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${totalWeekMinutes}${t.minutesShort} ${t.studyTime.toLowerCase()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Bar chart row
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < dailyStats.length; i++) ...[
                    Expanded(
                      child: _DayBar(
                        stat: dailyStats[i],
                        maxMinutes: maxMinutes,
                        isSelected: selectedIndex == i,
                        t: t,
                        onTap: () => onSelectDay(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Selected day details or prompt
            if (selectedIndex != null &&
                selectedIndex! >= 0 &&
                selectedIndex! < dailyStats.length) ...[
              _SelectedDayBanner(
                stat: dailyStats[selectedIndex!],
                t: t,
              ),
            ] else if (totalWeekMinutes == 0) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    t.noStudyDataYet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.stat,
    required this.maxMinutes,
    required this.isSelected,
    required this.t,
    required this.onTap,
  });

  final DailyStudyStat stat;
  final int maxMinutes;
  final bool isSelected;
  final AppText t;
  final VoidCallback onTap;

  static const List<String> _dayNamesEn = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  static const List<String> _dayNamesHi = [
    'सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dayOfWeek = stat.date.weekday - 1;
    final dayLabel = t.isHindi
        ? _dayNamesHi[dayOfWeek % 7]
        : _dayNamesEn[dayOfWeek % 7];

    final ratio = maxMinutes <= 0
        ? 0.0
        : (stat.studyMinutes / maxMinutes).clamp(0.0, 1.0);
    const maxBarHeight = 96.0;
    final barHeight = math.max(6.0, ratio * maxBarHeight);

    final hasActivity = stat.studyMinutes > 0 || stat.attemptCount > 0;
    final barColor = isSelected
        ? scheme.tertiary
        : hasActivity
            ? scheme.primary
            : scheme.outlineVariant.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Accuracy badge or attempts dot
          if (stat.attemptCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: stat.accuracyPercentage >= 60
                    ? Colors.green.withValues(alpha: 0.2)
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stat.accuracyPercentage.round()}%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: stat.accuracyPercentage >= 60
                      ? Colors.green
                      : scheme.onErrorContainer,
                ),
              ),
            )
          else
            const SizedBox(height: 15),

          const SizedBox(height: 6),

          // Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: barHeight,
            width: isSelected ? 18 : 14,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(7),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: scheme.tertiary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Day label
          Text(
            dayLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDayBanner extends StatelessWidget {
  const _SelectedDayBanner({
    required this.stat,
    required this.t,
  });

  final DailyStudyStat stat;
  final AppText t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateStr = '${stat.date.day}/${stat.date.month}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              dateStr,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${stat.studyMinutes} ${t.studyTime.toLowerCase()} • '
              '${stat.attemptCount} ${t.totalAttempts.toLowerCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (stat.attemptCount > 0)
            Text(
              '${stat.accuracyPercentage.toStringAsFixed(0)}% ${t.accuracy.toLowerCase()}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: stat.accuracyPercentage >= 60
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
        ],
      ),
    );
  }
}
