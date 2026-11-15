import 'dart:convert';
import 'dart:io';

import '../data/paper_repository.dart';

/// Result of a question generation run.
class GenerationResult {
  const GenerationResult({
    required this.batchId,
    required this.referenceCount,
    required this.generatedCount,
    required this.durationMilliseconds,
  });

  final String batchId;
  final int referenceCount;
  final int generatedCount;
  final int durationMilliseconds;

  @override
  String toString() =>
      'GenerationResult(batch=$batchId, ref=$referenceCount, gen=$generatedCount, '
      '${durationMilliseconds}ms)';
}

/// Pipeline that collects reference questions from the database, sends them
/// to an LLM to generate new questions per category, and stores the results
/// in the `generated_questions` table.
///
/// The API key is not bundled — it must be supplied via [setApiKey] before
/// calling [generate]. Until a key is configured, [generate] throws a clear
/// [StateError] so the failure is obvious rather than silent.
class QuestionGenerationPipeline {
  QuestionGenerationPipeline({required this.repository});

  final PaperRepository repository;

  static const int _referenceLimit = 100;
  static const int _targetGenerated = 500;

  // LLM endpoint — configurable. Defaults to a placeholder that must be
  // replaced with the actual provider endpoint once the API key is known.
  String _apiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  String? _apiKey;
  String _model = 'gpt-4o-mini';

  /// Sets the LLM API key. Call this once the key is available.
  void setApiKey(String apiKey) {
    _apiKey = apiKey.trim();
  }

  /// Sets a custom LLM endpoint (optional).
  void setEndpoint(String baseUrl, {String? model}) {
    _apiBaseUrl = baseUrl.trim();
    if (model != null) _model = model.trim();
  }

  /// Returns whether an API key has been configured.
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Runs the full generation pipeline:
  ///   1. Fetch up to [_referenceLimit] reference questions (with categories)
  ///   2. Send to LLM with a prompt requesting [_targetGenerated] new questions
  ///   3. Parse the LLM response
  ///   4. Insert into `generated_questions`
  ///
  /// Returns a [GenerationResult] summary.
  Future<GenerationResult> generate() async {
    if (!isConfigured) {
      throw StateError(
        'LLM API key not configured. Call QuestionGenerationPipeline.setApiKey() '
        'with your API key before generating questions.',
      );
    }

    final start = DateTime.now().millisecondsSinceEpoch;
    final batchId = 'gen_${DateTime.now().millisecondsSinceEpoch}';

    // Step 1: Collect reference questions from the database.
    final referenceQuestions = await _fetchReferenceQuestions();
    if (referenceQuestions.isEmpty) {
      throw StateError(
        'No reference questions found in the database. Import at least one '
        'paper before running generation.',
      );
    }

    // Step 2: Build the LLM prompt.
    final prompt = _buildPrompt(referenceQuestions);

    // Step 3: Call the LLM API.
    final rawResponse = await _callLLM(prompt);

    // Step 4: Parse the response into generated questions.
    final generated = _parseLLMResponse(rawResponse, batchId);

    // Cap at target count.
    final toInsert = generated.take(_targetGenerated).toList();

    // Step 5: Store in the database.
    await _insertGeneratedQuestions(toInsert);

    final duration = DateTime.now().millisecondsSinceEpoch - start;
    return GenerationResult(
      batchId: batchId,
      referenceCount: referenceQuestions.length,
      generatedCount: toInsert.length,
      durationMilliseconds: duration,
    );
  }

  // -------------------------------------------------------------------------
  // Step 1 — Fetch reference questions
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchReferenceQuestions() async {
    final db = await repository.database;
    final rows = await db.query(
      'questions',
      columns: [
        'number',
        'text',
        'section',
        'marks',
        'category',
        'confidence',
        'page_number',
        'options',
      ],
      limit: _referenceLimit,
      orderBy: 'category ASC, order_index ASC, id ASC',
    );
    return rows.map((r) => {
          'number': r['number'] as String?,
          'text': r['text'] as String?,
          'section': r['section'] as String?,
          'marks': r['marks'] as num?,
          'category': r['category'] as String?,
          'confidence': r['confidence'] as num?,
          'page_number': r['page_number'] as int?,
          'options': r['options'] as String?,
        }).toList();
  }

  // -------------------------------------------------------------------------
  // Step 2 — Build prompt
  // -------------------------------------------------------------------------

  String _buildPrompt(List<Map<String, dynamic>> references) {
    // Group references by category for the prompt.
    final byCategory = <String, List<Map<String, dynamic>>>{};
    for (final q in references) {
      final cat = (q['category'] as String?) ?? 'General';
      byCategory.putIfAbsent(cat, () => []).add(q);
    }

    final categories = byCategory.keys.toList()..sort();
    final catSummary = categories.map((c) => '- $c: ${byCategory[c]!.length} questions').join('\n');

    final refSamples = <String>[];
    int shown = 0;
    for (final cat in categories) {
      final qs = byCategory[cat]!;
      final take = qs.length > 2 ? 2 : qs.length;
      for (var i = 0; i < take && shown < 20; i++) {
        final q = qs[i];
        refSamples.add(
          '  [${q['category']}] Q${q['number']} (${q['section']}): ${q['text']}',
        );
        shown++;
      }
    }

    return '''
You are an expert exam-question author. Generate exactly 500 new exam questions
based on the reference questions and categories below.

REFERENCE CATEGORIES AND COUNTS:
$catSummary

REFERENCE QUESTION SAMPLES (first 20 shown):
${refSamples.join('\n')}

INSTRUCTIONS:
- Generate exactly 500 questions total.
- Distribute them across the categories above in proportion to their reference counts.
- For each question, provide: number, text, section, marks (numeric or null), category, page_number, confidence (0.0-1.0), and options (array of {label, text} for MCQ, empty array for non-MCQ).
- Output MUST be a single valid JSON array of question objects. No markdown fences, no extra text.
- Each object must have these keys: number, text, section, marks, category, page_number, confidence, options.
- Keep questions realistic, varied in difficulty, and appropriate for school-level exams.

Example object:
{"number":"1","text":"What is the capital of France?","section":"Section A","marks":2,"category":"Geography","page_number":1,"confidence":0.95,"options":[{"label":"A","text":"Paris"},{"label":"B","text":"London"}]}
''';
  }

  // -------------------------------------------------------------------------
  // Step 3 — Call LLM API
  // -------------------------------------------------------------------------

  Future<String> _callLLM(String prompt) async {
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are an expert exam-question author. Output only valid JSON arrays.',
        },
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.7,
      'max_tokens': 8000,
      'response_format': {'type': 'json_object'},
    });

    final client = HttpClient();
    try {
      final uri = Uri.parse(_apiBaseUrl);
      final request = await client.openUrl('POST', uri);
      request.headers.contentType = ContentType.json;
      request.headers.add('Authorization', 'Bearer $_apiKey');
      request.headers.add('X-Requested-With', 'SetYourRank');
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw StateError(
          'LLM API returned status ${response.statusCode}: $responseBody',
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw StateError('LLM API returned no choices: $responseBody');
      }

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw StateError('LLM API returned empty content: $responseBody');
      }

      return content.trim();
    } on StateError {
      rethrow;
    } catch (e) {
      throw StateError('LLM API call failed: $e');
    } finally {
      client.close();
    }
  }

  // -------------------------------------------------------------------------
  // Step 4 — Parse LLM response
  // -------------------------------------------------------------------------

  List<Map<String, dynamic>> _parseLLMResponse(String raw, String batchId) {
    // The LLM may return a JSON array directly, or wrapped in an object.
    String content = raw.trim();
    // Strip possible markdown code fences.
    if (content.startsWith('```')) {
      content = content.replaceFirst(RegExp(r'^```[a-zA-Z]*\n'), '');
      content = content.replaceFirst(RegExp(r'\n```$'), '');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      // Try to find a JSON array inside the text.
      final arrayStart = content.indexOf('[');
      final arrayEnd = content.lastIndexOf(']');
      if (arrayStart == -1 || arrayEnd == -1 || arrayEnd <= arrayStart) {
        throw StateError('LLM response did not contain a valid JSON array.');
      }
      decoded = jsonDecode(content.substring(arrayStart, arrayEnd + 1));
    }

    if (decoded is Map) {
      // Wrapped in an object — look for an array field.
      final candidates = <String, dynamic>{};
      decoded.forEach((k, v) {
        if (v is List) candidates[k] = v;
      });
      if (candidates.isEmpty) {
        throw StateError('LLM response object contained no array field.');
      }
      // Use the largest array.
      final best = candidates.entries.reduce((a, b) =>
          a.value.length > b.value.length ? a : b);
      decoded = best.value;
    }

    if (decoded is! List) {
      throw StateError('LLM response was not a JSON array or object with an array.');
    }

    final questions = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final text = (item['text'] as String?)?.trim();
      if (text == null || text.isEmpty) continue;

      questions.add({
        'number': (item['number'] as String?)?.trim() ?? '',
        'text': text,
        'section': (item['section'] as String?)?.trim() ?? '',
        'marks': (item['marks'] as num?)?.toDouble(),
        'category': (item['category'] as String?)?.trim() ?? 'General',
        'page_number': (item['page_number'] as int?) ?? 1,
        'confidence': ((item['confidence'] as num?) ?? 0.5).toDouble(),
        'options': (item['options'] as List?) ?? const [],
        'batch_id': batchId,
      });
    }

    if (questions.isEmpty) {
      throw StateError('LLM response contained no valid questions.');
    }

    return questions;
  }

  // -------------------------------------------------------------------------
  // Step 5 — Insert into database
  // -------------------------------------------------------------------------

  Future<void> _insertGeneratedQuestions(List<Map<String, dynamic>> questions) async {
    final db = await repository.database;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final q in questions) {
      final optionsRaw = (q['options'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((o) => {
                'label': (o['label'] as String?) ?? '',
                'text': (o['text'] as String?) ?? '',
              })
          .toList();

      batch.insert('generated_questions', {
        'number': q['number'] as String,
        'text': q['text'] as String,
        'section': q['section'] as String,
        'marks': q['marks'],
        'category': q['category'] as String,
        'confidence': q['confidence'] as double,
        'needs_review': 1,
        'page_number': q['page_number'] as int,
        'options_json': jsonEncode(optionsRaw),
        'raw_block': '',
        'source_category': q['category'] as String,
        'generation_batch': q['batch_id'] as String,
        'created_at': now,
      });
    }

    await batch.commit(noResult: true);
  }
}
