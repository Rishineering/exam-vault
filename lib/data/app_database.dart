import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite connection and schema.
///
/// Schema v5:
///   papers                - one row per imported question paper
///   questions             - one row per extracted question (+ difficulty, importance, is_pyq, exam_year, exam_name)
///   app_settings          - key/value app settings
///   generated_questions   - LLM-generated questions stored separately
///   user_profiles         - user's exam profile (target exam, language, target date)
///   subjects              - user-defined/customizable subjects
///   syllabus_topics       - topics under each subject
///   question_topics       - mapping questions -> syllabus topics (many-to-many)
///   mock_tests            - test metadata
///   mock_test_attempts    - user attempts
///   attempt_answers       - per-question answers in an attempt
///   question_explanations - explanations per question (EN/HI)
///   bookmarks             - user bookmarked questions
///   revision_schedule     - spaced repetition queue
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;
    final opened = await _open();
    _database = opened;
    return opened;
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, 'exam_vault.db');
    return openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE papers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            file_name TEXT NOT NULL,
            source_type TEXT NOT NULL,
            extraction_method TEXT NOT NULL,
            page_count INTEGER NOT NULL DEFAULT 0,
            question_count INTEGER NOT NULL DEFAULT 0,
            review_count INTEGER NOT NULL DEFAULT 0,
            average_confidence REAL NOT NULL DEFAULT 0,
            exam_year INTEGER,
            subject TEXT,
            class_name TEXT,
            duration TEXT,
            total_marks REAL,
            exam_name TEXT,
            warnings TEXT NOT NULL DEFAULT '[]',
            raw_text TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            paper_id INTEGER NOT NULL,
            number TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            section TEXT NOT NULL DEFAULT '',
            text TEXT NOT NULL,
            marks REAL,
            options TEXT NOT NULL DEFAULT '[]',
            page_number INTEGER NOT NULL DEFAULT 1,
            category TEXT NOT NULL DEFAULT '',
            difficulty TEXT NOT NULL DEFAULT 'Medium',
            importance TEXT NOT NULL DEFAULT 'Medium',
            correct_option TEXT,
            is_pyq INTEGER NOT NULL DEFAULT 0,
            exam_year INTEGER,
            exam_name TEXT,
            confidence REAL NOT NULL DEFAULT 0,
            needs_review INTEGER NOT NULL DEFAULT 1,
            warnings TEXT NOT NULL DEFAULT '[]',
            raw_block TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (paper_id) REFERENCES papers (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_questions_paper ON questions (paper_id, order_index)',
        );
        await db.execute('''
          CREATE TABLE app_settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE generated_questions (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            number         TEXT    NOT NULL,
            text           TEXT    NOT NULL,
            section        TEXT    NOT NULL DEFAULT '',
            marks          REAL,
            category       TEXT    NOT NULL DEFAULT '',
            correct_option TEXT,
            confidence     REAL    NOT NULL DEFAULT 0,
            needs_review   INTEGER NOT NULL DEFAULT 1,
            page_number    INTEGER NOT NULL DEFAULT 1,
            options_json   TEXT    NOT NULL DEFAULT '[]',
            raw_block      TEXT    NOT NULL DEFAULT '',
            source_category TEXT   NOT NULL DEFAULT '',
            generation_batch TEXT  NOT NULL DEFAULT '',
            created_at     INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_generated_questions_category ON generated_questions (category)',
        );
        await db.execute(
          'CREATE INDEX idx_generated_questions_batch ON generated_questions (generation_batch)',
        );
        await db.execute('''
          CREATE TABLE user_profiles (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            target_exam    TEXT    NOT NULL DEFAULT '',
            target_date    TEXT,
            language       TEXT    NOT NULL DEFAULT 'en',
            profile_setup  INTEGER NOT NULL DEFAULT 0,
            created_at     INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE subjects (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            color       TEXT    NOT NULL DEFAULT '#3554D1',
            weight      REAL    NOT NULL DEFAULT 1.0,
            is_active   INTEGER NOT NULL DEFAULT 1,
            created_at  INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE syllabus_topics (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_id  INTEGER NOT NULL,
            name        TEXT    NOT NULL,
            is_completed INTEGER NOT NULL DEFAULT 0,
            total_questions INTEGER NOT NULL DEFAULT 0,
            covered_questions INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_syllabus_topics_subject ON syllabus_topics (subject_id)',
        );
        await db.execute('''
          CREATE TABLE question_topics (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id  INTEGER NOT NULL,
            topic_id     INTEGER NOT NULL,
            FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE,
            FOREIGN KEY (topic_id) REFERENCES syllabus_topics (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_question_topics_question ON question_topics (question_id)',
        );
        await db.execute(
          'CREATE INDEX idx_question_topics_topic ON question_topics (topic_id)',
        );
        await db.execute('''
          CREATE TABLE mock_tests (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            title           TEXT    NOT NULL,
            exam_profile    TEXT    NOT NULL DEFAULT '',
            subject_filter  TEXT,
            topic_filter    TEXT,
            difficulty_filter TEXT,
            question_count  INTEGER NOT NULL DEFAULT 0,
            duration_minutes INTEGER NOT NULL DEFAULT 0,
            is_pyq_only     INTEGER NOT NULL DEFAULT 0,
            created_at      INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE mock_test_attempts (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            test_id        INTEGER NOT NULL,
            score          INTEGER NOT NULL DEFAULT 0,
            total          INTEGER NOT NULL DEFAULT 0,
            percentage     REAL    NOT NULL DEFAULT 0,
            time_taken     INTEGER NOT NULL DEFAULT 0,
            started_at     INTEGER NOT NULL,
            completed_at   INTEGER,
            FOREIGN KEY (test_id) REFERENCES mock_tests (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE attempt_answers (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            attempt_id  INTEGER NOT NULL,
            question_id INTEGER NOT NULL,
            user_answer TEXT,
            is_correct  INTEGER NOT NULL DEFAULT 0,
            time_spent  INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (attempt_id) REFERENCES mock_test_attempts (id) ON DELETE CASCADE,
            FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE question_explanations (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id   INTEGER NOT NULL,
            language      TEXT    NOT NULL DEFAULT 'en',
            explanation   TEXT    NOT NULL,
            source        TEXT,
            FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_question_explanations_question ON question_explanations (question_id)',
        );
        await db.execute('''
          CREATE TABLE bookmarks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id INTEGER NOT NULL UNIQUE,
            created_at  INTEGER NOT NULL,
            FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE revision_schedule (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id    INTEGER NOT NULL,
            next_review    INTEGER NOT NULL,
            interval_days  INTEGER NOT NULL DEFAULT 1,
            ease_factor    REAL    NOT NULL DEFAULT 2.5,
            FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_revision_schedule_next ON revision_schedule (next_review)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE questions ADD COLUMN category TEXT NOT NULL DEFAULT \'\'',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE app_settings (
              key   TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE generated_questions (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              number         TEXT    NOT NULL,
              text           TEXT    NOT NULL,
              section        TEXT    NOT NULL DEFAULT '',
              marks          REAL,
              category       TEXT    NOT NULL DEFAULT '',
              confidence     REAL    NOT NULL DEFAULT 0,
              needs_review   INTEGER NOT NULL DEFAULT 1,
              page_number    INTEGER NOT NULL DEFAULT 1,
              options_json   TEXT    NOT NULL DEFAULT '[]',
              raw_block      TEXT    NOT NULL DEFAULT '',
              source_category TEXT   NOT NULL DEFAULT '',
              generation_batch TEXT  NOT NULL DEFAULT '',
              created_at     INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_generated_questions_category ON generated_questions (category)',
          );
          await db.execute(
            'CREATE INDEX idx_generated_questions_batch ON generated_questions (generation_batch)',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE questions ADD COLUMN correct_option TEXT',
          );
          await db.execute(
            'ALTER TABLE generated_questions ADD COLUMN correct_option TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE questions ADD COLUMN difficulty TEXT NOT NULL DEFAULT \'Medium\'',
          );
          await db.execute(
            'ALTER TABLE questions ADD COLUMN importance TEXT NOT NULL DEFAULT \'Medium\'',
          );
          await db.execute(
            'ALTER TABLE questions ADD COLUMN is_pyq INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE questions ADD COLUMN exam_year INTEGER',
          );
          await db.execute(
            'ALTER TABLE questions ADD COLUMN exam_name TEXT',
          );
          await db.execute('''
            CREATE TABLE user_profiles (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              target_exam    TEXT    NOT NULL DEFAULT '',
              target_date    TEXT,
              language       TEXT    NOT NULL DEFAULT 'en',
              profile_setup  INTEGER NOT NULL DEFAULT 0,
              created_at     INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE subjects (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              name        TEXT    NOT NULL,
              color       TEXT    NOT NULL DEFAULT '#3554D1',
              weight      REAL    NOT NULL DEFAULT 1.0,
              is_active   INTEGER NOT NULL DEFAULT 1,
              created_at  INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE syllabus_topics (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              subject_id  INTEGER NOT NULL,
              name        TEXT    NOT NULL,
              is_completed INTEGER NOT NULL DEFAULT 0,
              total_questions INTEGER NOT NULL DEFAULT 0,
              covered_questions INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_syllabus_topics_subject ON syllabus_topics (subject_id)',
          );
          await db.execute('''
            CREATE TABLE question_topics (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              question_id  INTEGER NOT NULL,
              topic_id     INTEGER NOT NULL,
              FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE,
              FOREIGN KEY (topic_id) REFERENCES syllabus_topics (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_question_topics_question ON question_topics (question_id)',
          );
          await db.execute(
            'CREATE INDEX idx_question_topics_topic ON question_topics (topic_id)',
          );
          await db.execute('''
            CREATE TABLE mock_tests (
              id              INTEGER PRIMARY KEY AUTOINCREMENT,
              title           TEXT    NOT NULL,
              exam_profile    TEXT    NOT NULL DEFAULT '',
              subject_filter  TEXT,
              topic_filter    TEXT,
              difficulty_filter TEXT,
              question_count  INTEGER NOT NULL DEFAULT 0,
              duration_minutes INTEGER NOT NULL DEFAULT 0,
              is_pyq_only     INTEGER NOT NULL DEFAULT 0,
              created_at      INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE mock_test_attempts (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              test_id        INTEGER NOT NULL,
              score          INTEGER NOT NULL DEFAULT 0,
              total          INTEGER NOT NULL DEFAULT 0,
              percentage     REAL    NOT NULL DEFAULT 0,
              time_taken     INTEGER NOT NULL DEFAULT 0,
              started_at     INTEGER NOT NULL,
              completed_at   INTEGER,
              FOREIGN KEY (test_id) REFERENCES mock_tests (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE attempt_answers (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              attempt_id  INTEGER NOT NULL,
              question_id INTEGER NOT NULL,
              user_answer TEXT,
              is_correct  INTEGER NOT NULL DEFAULT 0,
              time_spent  INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (attempt_id) REFERENCES mock_test_attempts (id) ON DELETE CASCADE,
              FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE question_explanations (
              id            INTEGER PRIMARY KEY AUTOINCREMENT,
              question_id   INTEGER NOT NULL,
              language      TEXT    NOT NULL DEFAULT 'en',
              explanation   TEXT    NOT NULL,
              source        TEXT,
              FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_question_explanations_question ON question_explanations (question_id)',
          );
          await db.execute('''
            CREATE TABLE bookmarks (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              question_id INTEGER NOT NULL UNIQUE,
              created_at  INTEGER NOT NULL,
              FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE revision_schedule (
              id             INTEGER PRIMARY KEY AUTOINCREMENT,
              question_id    INTEGER NOT NULL,
              next_review    INTEGER NOT NULL,
              interval_days  INTEGER NOT NULL DEFAULT 1,
              ease_factor    REAL    NOT NULL DEFAULT 2.5,
              FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_revision_schedule_next ON revision_schedule (next_review)',
          );
        }
      },
    );
  }

  Future<void> close() async {
    final existing = _database;
    _database = null;
    await existing?.close();
  }
}
