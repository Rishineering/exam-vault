import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_strings.dart';
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

  @override
  void dispose() {
    _subjectNameController.dispose();
    _topicNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = AppScope.read(context);
    await state.loadSubjects();
    await state.loadSyllabusTopics();
    if (mounted) setState(() {});
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
      if (mounted) setState(() {});
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
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isAddingTopic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = AppText.of(context);
    final activeSubjects = state.activeSubjects;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.syllabusTracker),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Overall progress header card
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
                    t.overallProgress,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${state.syllabusCompletionPercent.toStringAsFixed(0)}% ${t.markCompleted}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (state.syllabusCompletionPercent / 100).clamp(0.0, 1.0),
                    backgroundColor:
                        scheme.onPrimary.withValues(alpha: 0.2),
                    color: scheme.onPrimary,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.isHindi
                        ? '${activeSubjects.length} विषय • ${state.syllabusTopics.length} टॉपिक्स'
                        : '${activeSubjects.length} subject${activeSubjects.length == 1 ? '' : 's'} • ${state.syllabusTopics.length} topic${state.syllabusTopics.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Add Subject Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.addSubject,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _subjectNameController,
                      decoration: InputDecoration(
                        hintText: t.isHindi
                            ? 'उदा. भारतीय राजव्यवस्था, इतिहास, भूगोल'
                            : 'e.g. Indian Polity, History, Geography',
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
                            : Text(t.addSubject),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (activeSubjects.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school_rounded,
                          size: 64, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        t.noSubjectsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.noSubjectsBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final subject in activeSubjects) ...[
                _SubjectCard(
                  subject: subject,
                  state: state,
                  t: t,
                  isAddingTopic: _isAddingTopic,
                  topicController: _topicNameController,
                  onAddTopic: (subId) => _addTopic(state, subId),
                  onRemoveSubject: () => _confirmRemoveSubject(state, subject, t),
                  onEditTopic: (topic) => _editTopic(context, state, topic, t),
                  onRemoveTopic: (topic) => _confirmRemoveTopic(state, topic, t),
                ),
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveSubject(
      AppState state, Subject subject, AppText t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.isHindi ? 'विषय हटाएँ' : 'Remove Subject'),
        content: Text(
          t.isHindi
              ? '"${subject.name}" और इसके सभी टॉपिक हटाएँ?'
              : 'Remove "${subject.name}" and all its topics?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.removeSubject(subject.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmRemoveTopic(
      AppState state, SyllabusTopic topic, AppText t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.isHindi ? 'टॉपिक हटाएँ' : 'Remove Topic'),
        content: Text(
          t.isHindi ? '"${topic.name}" हटाएँ?' : 'Remove "${topic.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.removeSyllabusTopic(topic.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _editTopic(
    BuildContext context,
    AppState state,
    SyllabusTopic topic,
    AppText t,
  ) async {
    _topicNameController.text = topic.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.isHindi ? 'टॉपिक संपादित करें' : 'Edit Topic'),
        content: TextField(
          controller: _topicNameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: t.topicName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final updatedName = _topicNameController.text.trim();
      if (updatedName.isNotEmpty) {
        await state.updateSyllabusTopic(topic.copyWith(name: updatedName));
        _topicNameController.clear();
        if (mounted) setState(() {});
      }
    }
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final AppState state;
  final AppText t;
  final bool isAddingTopic;
  final TextEditingController topicController;
  final ValueChanged<int> onAddTopic;
  final VoidCallback onRemoveSubject;
  final ValueChanged<SyllabusTopic> onEditTopic;
  final ValueChanged<SyllabusTopic> onRemoveTopic;

  const _SubjectCard({
    required this.subject,
    required this.state,
    required this.t,
    required this.isAddingTopic,
    required this.topicController,
    required this.onAddTopic,
    required this.onRemoveSubject,
    required this.onEditTopic,
    required this.onRemoveTopic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topics = state.syllabusTopics
        .where((top) => top.subjectId == subject.id)
        .toList();
    final total = topics.fold<int>(0, (sum, top) => sum + top.totalQuestions);
    final covered =
        topics.fold<int>(0, (sum, top) => sum + top.coveredQuestions);
    final pct = total == 0 ? 0.0 : (covered / total) * 100;

    return Card(
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
                      int.parse(subject.color.replaceFirst('#', '0xFF')),
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
              t.isHindi
                  ? '${topics.length} टॉपिक • ${pct.toStringAsFixed(0)}% पूर्ण'
                  : '${topics.length} topic${topics.length == 1 ? '' : 's'} • ${pct.toStringAsFixed(0)}% complete',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onRemoveSubject,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.isHindi ? 'विषय-वस्तु (Topics)' : 'Topics',
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
                      t.isHindi ? 'अभी कोई टॉपिक नहीं जोड़ा गया' : 'No topics added yet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                for (final topic in topics) ...[
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: topic.isCompleted,
                      onChanged: (val) async {
                        await state.updateSyllabusTopic(
                          topic.copyWith(isCompleted: val ?? false),
                        );
                      },
                    ),
                    title: Text(
                      topic.name,
                      style: TextStyle(
                        decoration: topic.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      t.isHindi
                          ? '${topic.coveredQuestions}/${topic.totalQuestions} प्रश्न'
                          : '${topic.coveredQuestions}/${topic.totalQuestions} questions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          onPressed: () => onEditTopic(topic),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          onPressed: () => onRemoveTopic(topic),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: topicController,
                        decoration: InputDecoration(
                          hintText: t.isHindi
                              ? 'टॉपिक जोड़ें...'
                              : 'Add a topic...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => onAddTopic(subject.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: FilledButton.tonal(
                        onPressed: isAddingTopic
                            ? null
                            : () => onAddTopic(subject.id),
                        child: Text(t.isHindi ? 'जोड़ें' : 'Add'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
