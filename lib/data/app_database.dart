import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite connection and schema.
///
/// Schema v3:
///   papers        - one row per imported question paper
///   questions     - one row per extracted question
///   app_settings  - key/value app settings (e.g. onboarding / login state)
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
      version: 3,
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
      },
    );
  }

  Future<void> close() async {
    final existing = _database;
    _database = null;
    await existing?.close();
  }
}
