import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A minimal monthly calendar shown from the hamburger drawer.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    // Pad so the grid starts on the correct weekday.
    final startOffset = first.weekday % 7; // Mon=1..Sun=7 -> Sun=0
    final padded = <DateTime>[];
    for (var i = 0; i < startOffset; i++) {
      padded.add(DateTime.utc(1970, 1, 1)); // placeholder
    }
    for (var d = 1; d <= last.day; d++) {
      padded.add(DateTime(month.year, month.month, d));
    }
    // Pad tail to complete the last week.
    while (padded.length % 7 != 0) {
      padded.add(DateTime.utc(1970, 1, 1));
    }
    return padded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final days = _daysInMonth(_focusedMonth);
    final monthName = DateFormat.yMMM().format(_focusedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Month header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year,
                          _focusedMonth.month - 1);
                    }),
                  ),
                ),
                Text(
                  monthName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() {
                      _focusedMonth = DateTime(_focusedMonth.year,
                          _focusedMonth.month + 1);
                    }),
                  ),
                ),
              ],
            ),
          ),
          // Weekday labels
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: 7,
                    itemBuilder: (_, i) {
                      const labels = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      return Center(
                        child: Text(
                          labels[i],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: days.length,
                    itemBuilder: (_, i) {
                      final day = days[i];
                      final isPlaceholder = day.year == 1970;
                      final isToday = !isPlaceholder &&
                          day.year == now.year &&
                          day.month == now.month &&
                          day.day == now.day;
                      if (isPlaceholder) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isToday ? scheme.primary : null,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isToday ? scheme.onPrimary : null,
                            fontWeight: isToday ? FontWeight.w700 : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
