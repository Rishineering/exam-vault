import 'package:flutter/material.dart';

import '../app.dart';
import '../state/app_state.dart';

/// Performance Analytics screen.
///
/// Shows accuracy by subject, weak areas, overall stats and study time.
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

    if (!mounted) return;
    setState(() {
      _overallAccuracy = overall;
      _totalAttempts = attempts;
      _totalStudyMinutes = minutes;
      _accuracyBySubject = bySubject;
      _weakAreas = weak;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Analytics'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                          'Overview',
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
                                label: 'Overall Accuracy',
                                value: '${_overallAccuracy.toStringAsFixed(0)}%',
                                icon: Icons.show_chart_rounded,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: 'Total Attempts',
                                value: _totalAttempts.toString(),
                                icon: Icons.assignment_rounded,
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: 'Study Time',
                                value: _formatMinutes(_totalStudyMinutes),
                                icon: Icons.access_time_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_accuracyBySubject.isNotEmpty) ...[
                    Text(
                      'Accuracy by Subject',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._accuracyBySubject.entries.map((entry) {
                      final acc = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(entry.key),
                          subtitle: LinearProgressIndicator(
                            value: acc / 100,
                            minHeight: 6,
                            backgroundColor:
                                scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                            color: acc >= 60
                                ? Colors.green
                                : acc >= 40
                                ? Colors.orange
                                : Colors.red,
                          ),
                          trailing: Text(
                            '${acc.toStringAsFixed(0)}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: acc >= 60
                                  ? Colors.green
                                  : acc >= 40
                                  ? Colors.orange
                                  : Colors.red,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                  if (_weakAreas.isNotEmpty) ...[
                    Text(
                      'Weak Areas (Needs Attention)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._weakAreas.map((area) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.warning_rounded,
                            color: Colors.orange,
                          ),
                          title: Text(
                            area,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          onTap: () {},
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Study Time Trend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('Chart coming soon'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
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
        Icon(icon, color: theme.colorScheme.onPrimary, size: 32),
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
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
