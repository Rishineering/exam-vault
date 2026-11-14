import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../state/app_state.dart';

/// Subject & Syllabus Coverage Tracker screen.
///
/// Users can add/remove subjects and syllabus topics, and view dynamic
/// completion progress calculated from stored questions and mock test data.
class SyllabusTrackerScreen extends StatefulWidget {
  const SyllabusTrackerScreen({super.key});

  @override
  State<SyllabusTrackerScreen> createState() => _SyllabusTrackerScreenState();
}

class _SyllabusTrackerScreenState extends State<SyllabusTrackerScreen> {
  final _subjectNameController = TextEditingController();
  final _topicNameController = TextEditingController();
  bool _isAddingSubject = false;
  bool _isAddingTopic = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadSubjects();
    await state.loadSyllabusTopics();
    setState(() {});
  }

  Future<void> _addSubject(AppState state) async {
    final name = _subjectNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isAddingSubject = true);
    try {
      final subject = Subject(
        id: 0,
        name: name,
        color: '#3554D1',
        weight: 1.0,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await state.addSubject(subject);
      _subjectNameController.clear();
      await state.loadSubjects();
      await state.loadSyllabusTopics();
      setState(() {});
    } finally {
      if (mounted) setState(() => _isAddingSubject = false);
    }
  }

  Future<void> _addTopic(AppState state, int subjectId) async {
    final name = _topicNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isAddingTopic = true);
    try {
      final topic = SyllabusTopic(
        id: 0,
        subjectId: subjectId,
        name: name,
        isCompleted: false,
        totalQuestions: 0,
        coveredQuestions: 0,
      );
      await state.addSyllabusTopic(topic);
      _topicNameController.clear();
      await state.loadSyllabusTopics(subjectId: subjectId);
      setState(() {});
    } finally {
      if (mounted) setState(() => _isAddingTopic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeSubjects = state.activeSubjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabus Tracker'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
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
                    'Overall Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.syllabusCompletionPercent.toStringAsFixed(0)}% Complete',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: state.syllabusCompletionPercent / 100,
                    backgroundColor:
                        scheme.onPrimary.withValues(alpha: 0.2),
                    color: scheme.onPrimary,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${activeSubjects.length} subject${activeSubjects.length == 1 ? '' : 's'} '
                    '• ${state.syllabusTopics.length} topic${state.syllabusTopics.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Subject',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _subjectNameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Indian Polity, History, Geography',
                        prefixIcon: const Icon(Icons.add_circle_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _addSubject(state),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton.tonal(
                        onPressed: _isAddingSubject
                            ? null
                            : () => _addSubject(state),
                        child: _isAddingSubject
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Add Subject'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (activeSubjects.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded,
                        size: 64, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No subjects yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first subject to start tracking syllabus coverage.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...activeSubjects.map((subject) {
                final topics = state.syllabusTopics
                    .where((t) => t.subjectId == subject.id)
                    .toList();
                final total = topics.fold<int>(
                  0,
                  (sum, t) => sum + t.totalQuestions,
                );
                final covered = topics.fold<int>(
                  0,
                  (sum, t) => sum + t.coveredQuestions,
                );
                final pct = total == 0 ? 0.0 : (covered / total) * 100;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(subject.color.replaceFirst('#', '0xFF')),
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              subject.name.isNotEmpty
                                  ? subject.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Color(
                                  int.parse(
                                      subject.color.replaceFirst('#', '0xFF')),
                                ),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          subject.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${topics.length} topic${topics.length == 1 ? '' : 's'} • '
                          '${pct.toStringAsFixed(0)}% complete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _confirmRemoveSubject(state, subject),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Topics',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (topics.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'No topics added yet',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ...topics.map((topic) {
                              final tpct =
                                  topic.totalQuestions == 0
                                      ? 0.0
                                      : (topic.coveredQuestions /
                                              topic.totalQuestions) *
                                          100;
                              return ListTile(
                                dense: true,
                                leading: Checkbox(
                                  value: topic.isCompleted,
                                  onChanged: (val) async {
                                    await state.updateSyllabusTopic(
                                      topic.copyWith(
                                          isCompleted: val ?? false),
                                    );
                                  },
                                ),
                                title: Text(topic.name),
                                subtitle: Text(
                                  '${topic.coveredQuestions}/${topic.totalQuestions} questions '
                                  '(${tpct.toStringAsFixed(0)}%)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded,
                                          size: 20),
                                      onPressed: () =>
                                          _editTopic(context, state, topic),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons
                                          .delete_outline_rounded),
                                      onPressed: () =>
                                          _confirmRemoveTopic(state, topic),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _topicNameController,
                                      decoration: InputDecoration(
                                        hintText: 'Add a topic...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      onSubmitted: (_) =>
                                          _addTopic(state, subject.id),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 40,
                                    child: FilledButton.tonal(
                                      onPressed: _isAddingTopic
                                          ? null
                                          : () => _addTopic(state,
                                              subject.id),
                                      child: const Text('Add'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveSubject(
      AppState state, Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Subject'),
        content: Text('Remove "${subject.name}" and all its topics?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.removeSubject(subject.id);
      setState(() {});
    }
  }

  Future<void> _confirmRemoveTopic(
      AppState state, SyllabusTopic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Topic'),
        content: Text('Remove "${topic.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.removeSyllabusTopic(topic.id);
      setState(() {});
    }
  }

  Future<void> _editTopic(
      BuildContext context, AppState state, SyllabusTopic topic) async {
    _topicNameController.text = topic.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Topic'),
        content: TextField(
          controller: _topicNameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Topic name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed == true && _topicNameController.text.trim().isNotEmpty) {
      await state.updateSyllabusTopic(
        topic.copyWith(name: _topicNameController.text.trim()),
      );
      _topicNameController.clear();
      await state.loadSyllabusTopics(subjectId: topic.subjectId);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subjectNameController.dispose();
    _topicNameController.dispose();
    super.dispose();
  }
}
