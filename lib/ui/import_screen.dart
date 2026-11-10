import 'package:flutter/material.dart';

import '../app.dart';
import '../services/document_reader.dart';
import 'paper_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.file});

  final SelectedFile file;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ValueNotifier<ImportProgress> _progress =
      ValueNotifier(const ImportProgress(stage: ImportStage.reading));

  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    setState(() => _error = null);
    _progress.value = const ImportProgress(stage: ImportStage.reading);

    try {
      final paperId = await state.importFile(
        widget.file,
        onProgress: (progress) => _progress.value = progress,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaperScreen(paperId: paperId)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importing paper'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _error != null
                    ? _buildError(context, scheme)
                    : _buildProgress(context, scheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, ColorScheme scheme) {
    return ValueListenableBuilder<ImportProgress>(
      valueListenable: _progress,
      builder: (context, progress, _) {
        final ocr = progress.stage == ImportStage.runningOcr;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: ocr
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: scheme.onPrimaryContainer,
                        ),
                      )
                    : Icon(
                        Icons.auto_awesome_rounded,
                        size: 34,
                        color: scheme.onPrimaryContainer,
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              progress.stage.label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.file.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.overall.clamp(0, 1),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              progress.detail.isNotEmpty
                  ? progress.detail
                  : '${(progress.overall * 100).round()}% complete',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (ocr) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: scheme.onTertiaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This looks like a scanned PDF, so ExamVault is '
                        'reading it with on-device OCR. This can take a minute.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildError(BuildContext context, ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
        const SizedBox(height: 16),
        Text(
          'Import failed',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _friendlyMessage(_error!),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _run,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Choose another file'),
        ),
      ],
    );
  }

  String _friendlyMessage(Object error) {
    if (error is FormatException) return error.message;
    final text = error.toString();
    if (text.contains('password') || text.contains('encrypted')) {
      return 'This PDF is password protected. Remove the password and try again.';
    }
    return 'Something went wrong while reading this file.\n\n$text';
  }
}
