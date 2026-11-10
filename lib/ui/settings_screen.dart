import 'package:flutter/material.dart';

/// Static help, privacy and about information.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About & help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: scheme.onPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fact_check_rounded,
                        color: scheme.onPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ExamVault',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Version $version',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimary.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Turn previous-year question papers into a clean, editable '
                  'question table — one question per row — without sending '
                  'anything off your device.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _InfoCard(
            icon: Icons.auto_awesome_rounded,
            title: 'How extraction works',
            body: 'ExamVault reads the text layer of a digital PDF, keeps the '
                'position of every line, removes repeated headers and footers, '
                'then detects question numbers, sections, marks and '
                'multiple-choice options with a rule-based parser. Scanned '
                'PDFs are rendered and read with on-device OCR automatically.',
          ),
          const _InfoCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Tips for the best accuracy',
            body: '• Use the original paper PDF rather than a photo when you '
                'can.\n'
                '• Prefer papers with clear question numbers such as "1.", '
                '"Q1." or "14(a)".\n'
                '• Keep multi-column layouts clean; the parser reads columns '
                'left to right.\n'
                '• Check rows flagged for review first, then correct any '
                'mistake by tapping the row.\n'
                '• If a PDF is only an image, OCR results can contain small '
                'character errors; review those rows.',
          ),
          const _InfoCard(
            icon: Icons.table_chart_outlined,
            title: 'The question table',
            body: 'Every row stores the question number, section, question '
                'text, marks, options, page number, a confidence score and a '
                'review flag. Tap any row to edit it. Use the share button to '
                'export the table as a CSV file that opens in Excel, Google '
                'Sheets or Numbers.',
          ),
          const _InfoCard(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy',
            body: 'All parsing, OCR and storage happen on this device. '
                'ExamVault does not use an internet connection, accounts or '
                'analytics. Your papers and extracted questions stay in the '
                'app\'s private database until you delete them.',
          ),
          const _InfoCard(
            icon: Icons.description_outlined,
            title: 'Supported files',
            body: 'PDF (.pdf) with an embedded text layer or scanned pages, '
                'and plain text (.txt) files in UTF-8, UTF-16 or Latin-1. '
                'Text files should contain numbered questions, one paper per '
                'file.',
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ExamVault $version • Offline-first',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
