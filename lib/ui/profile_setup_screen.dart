import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'home_screen.dart';

/// Profile setup screen — users select their target exam, language, and
/// preferences during first signup. Shown after login before reaching home.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetExamController = TextEditingController();
  final _targetDateController = TextEditingController();
  String _selectedLanguage = 'en';
  bool _saving = false;

  static const List<Map<String, String>> _exams = [
    {'label': 'UPSC Civil Services', 'value': 'upsc'},
    {'label': 'SSC CGL', 'value': 'ssc_cgl'},
    {'label': 'SSC CHSL', 'value': 'ssc_chsl'},
    {'label': 'IBPS PO', 'value': 'ibps_po'},
    {'label': 'IBPS Clerk', 'value': 'ibps_clerk'},
    {'label': 'RRB NTPC', 'value': 'rrb_ntpc'},
    {'label': 'RRB Group D', 'value': 'rrb_group_d'},
    {'label': 'State PSC', 'value': 'state_psc'},
    {'label': 'Other', 'value': 'other'},
  ];

  static const List<Map<String, String>> _languages = [
    {'label': 'English', 'value': 'en'},
    {'label': 'Hindi', 'value': 'hi'},
    {'label': 'Bilingual (EN + HI)', 'value': 'bilingual'},
  ];

  @override
  void dispose() {
    _targetExamController.dispose();
    _targetDateController.dispose();
    super.dispose();
  }

  Future<void> _handleSave(BuildContext context, AppState state) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final profile = UserProfile(
        id: 0,
        targetExam: _targetExamController.text.trim(),
        targetDate: _targetDateController.text.trim().isEmpty
            ? null
            : _targetDateController.text.trim(),
        language: _selectedLanguage,
        profileSetup: true,
        createdAt: DateTime.now(),
      );

      await state.saveUserProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Tell us about your exam',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This helps us tailor questions, syllabus tracking and '
                  'analytics to your target exam.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Target Exam',
                          prefixIcon: Icon(Icons.school_rounded),
                        ),
                        value: _exams.first['value'],
                        items: _exams
                            .map(
                              (e) => DropdownMenuItem(
                                value: e['value'],
                                child: Text(e['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _targetExamController.text = val;
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select an exam';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _targetExamController,
                        decoration: const InputDecoration(
                          labelText: 'Exam Name (custom)',
                          hintText: 'e.g. UPSC CSE 2025',
                          prefixIcon: Icon(Icons.edit_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an exam name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _targetDateController,
                        decoration: const InputDecoration(
                          labelText: 'Target Exam Date (optional)',
                          hintText: 'DD/MM/YYYY',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Preferred Language',
                          prefixIcon: Icon(Icons.language_rounded),
                        ),
                        value: _selectedLanguage,
                        items: _languages
                            .map(
                              (e) => DropdownMenuItem(
                                value: e['value'],
                                child: Text(e['label']!),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLanguage = val);
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving
                              ? null
                              : () => _handleSave(context, AppScope.read(context)),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
