================================================================================
                         EXAMVAULT - PROJECT OVERVIEW
================================================================================

Project path : /home/rj12_rj1/Desktop/Dev Projects (OC)/exam-vault
Generated    : Thu Nov 12 2026
Analyst      : Principal Android Application Developer

--------------------------------------------------------------------------------
1. WHAT IS THIS APP?
--------------------------------------------------------------------------------

ExamVault is an **Android-only Flutter application** that turns previous-year
exam question papers into a clean, editable question table — one question per
row — entirely on the user's device.

It reads a PDF (digital or scanned) or a plain-text file, extracts the
questions, and stores them in a local SQLite database that the user can review,
correct, and export to CSV.

Key characteristics:
- No account, no server, no network calls (offline-first).
- All data is stored in the app's private database.
- Material 3 light/dark UI.
- Pure-Dart extraction engine (no Flutter/plugin imports), fully unit-testable
  on a desktop VM.

--------------------------------------------------------------------------------
2. FEATURES
--------------------------------------------------------------------------------

- Import PDF or TXT via the system file picker.
- Digital PDFs: reads the embedded text layer together with line positions,
  handling headers/footers and two-column layouts.
- Scanned PDFs: renders pages (pdfx) and runs on-device OCR via ML Kit (Latin
  model bundled in the APK) when there is no usable text layer.
- Rule-based parser detects question numbers (`1.`, `Q1.`, `1)`, `(1)`, `14(a)`,
  Roman numerals), sections (`Section A`, `SECTION B`, `Part I`), marks (`[2]`,
  `(2 marks)`, `3 M`), and MCQ options (uppercase `(A)`/`A)` and numeric `1)`).
- Metadata extraction: exam name, subject, year, class, duration, total marks.
- Confidence score + review flag per question, with a human-readable reason for
  every flag.
- Review workflow: search, filter (All / Needs review / MCQ), tap any row to
  edit number, section, text, marks or options.
- Paper management: rename, view raw extracted text, delete, export.
- CSV export through the Android share sheet (opens in Excel, Sheets, etc.).

--------------------------------------------------------------------------------
3. TECH STACK
--------------------------------------------------------------------------------

| Concern              | Choice                                              |
|----------------------|-----------------------------------------------------|
| Framework            | Flutter / Dart                                      |
| Target               | Android only (minSdk 24, compile/targetSdk 36)      |
| Package name         | com.examvault.exam_vault                            |
| App label            | ExamVault                                           |
| Version              | 1.0.0+1                                             |
| PDF text layer       | syncfusion_flutter_pdf (layout-aware TextLine.bounds) |
| Scanned-PDF render   | pdfx                                                |
| OCR                  | google_mlkit_text_recognition (bundled Latin model) |
| Storage              | sqflite (no code generation)                        |
| File picking         | file_picker                                         |
| Sharing/export       | share_plus                                          |
| Formatting           | intl                                                |
| Icons                | cupertino_icons                                     |
| State management     | plain ChangeNotifier + InheritedNotifier scope (AppScope) |

--------------------------------------------------------------------------------
4. PROJECT LAYOUT
--------------------------------------------------------------------------------

lib/
  main.dart                        App entry point
  app.dart                         MaterialApp + AppScope wiring
  core/                            Pure-Dart extraction engine (no plugins)
    models.dart                    LayoutLine, RawDocument, ParsedQuestion, …
    text/normalize.dart            Unicode/whitespace normalisation
    parsing/patterns.dart          Shared regexes
    parsing/metadata_parser.dart   Exam name, subject, year, marks, …
    parsing/question_parser.dart   Segmentation, marks, options, confidence
    layout/layout_processor.dart   Header/footer removal, column ordering
    extraction/raw_document_builder.dart
    extraction/extraction_quality.dart
  services/
    pdf_text_extractor.dart        Embedded-text PDF extraction
    ocr_extractor.dart             pdfx rendering + ML Kit OCR
    document_reader.dart           TXT decoding, PDF dispatch, OCR fallback
    export_service.dart            CSV building + share sheet
  data/
    models.dart                    PaperRecord, StoredQuestion, PaperDetail
    app_database.dart              SQLite schema + migrations
    paper_repository.dart          CRUD
  state/app_state.dart             App-wide state and operations
  ui/
    home_screen.dart               Paper list + import button
    import_screen.dart             Progress + result of one import
    paper_screen.dart              Summary, search/filter, actions
    question_table.dart            Scrollable spreadsheet-style table
    question_edit_sheet.dart       Manual correction bottom sheet
    settings_screen.dart           About, tips, privacy

test/                              Unit, service, widget and integration tests
sample_exam_paper.txt              Sample input for end-to-end test
android/                           Android-specific Gradle + manifest + resources
pubspec.yaml                       Flutter package manifest + dependencies
pubspec.lock                       Locked dependency versions
analysis_options.yaml              Dart lint rules

--------------------------------------------------------------------------------
5. EXTRACTION PIPELINE
--------------------------------------------------------------------------------

file bytes
   │
   ├─ .txt ──────────────────────────────────────────────► decodeText (UTF-8/UTF-16/Latin-1)
   │
   └─ .pdf ──► embedded text layer? ──yes─► PdfTextExtractor (page + bounds)
                         │
                         └──no────────────────────────► pdfx render ► ML Kit OCR
   │
   ▼
RawDocument  (pages → LayoutLine with bounding boxes)
   │
   ▼
LayoutProcessor   remove repeated headers/footers, order columns
   │
   ▼
QuestionParser    split questions, sections, marks, options, confidence
   │
   ▼
PaperRepository   INSERT paper + questions (SQLite transaction)

--------------------------------------------------------------------------------
6. DATABASE SCHEMA (v3)
--------------------------------------------------------------------------------

CREATE TABLE papers (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  title              TEXT    NOT NULL,
  file_name          TEXT    NOT NULL,
  source_type        TEXT    NOT NULL,   -- pdf | txt
  extraction_method  TEXT    NOT NULL,   -- embeddedText | ocr | plainText
  page_count         INTEGER NOT NULL DEFAULT 0,
  question_count     INTEGER NOT NULL DEFAULT 0,
  review_count       INTEGER NOT NULL DEFAULT 0,
  average_confidence REAL    NOT NULL DEFAULT 0,
  exam_year          INTEGER,
  subject            TEXT,
  class_name         TEXT,
  duration           TEXT,
  total_marks        REAL,
  exam_name          TEXT,
  warnings           TEXT    NOT NULL DEFAULT '[]',
  raw_text           TEXT    NOT NULL DEFAULT '',
  created_at         INTEGER NOT NULL
);

CREATE TABLE questions (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  paper_id      INTEGER NOT NULL REFERENCES papers (id) ON DELETE CASCADE,
  number        TEXT    NOT NULL,
  order_index   INTEGER NOT NULL,
  text          TEXT    NOT NULL,
  section       TEXT    NOT NULL DEFAULT '',
  marks         REAL,
  options       TEXT    NOT NULL DEFAULT '[]',
  page_number   INTEGER NOT NULL DEFAULT 1,
  category      TEXT    NOT NULL DEFAULT '',   -- History / Geography / Social Science / Maths
  confidence    REAL    NOT NULL DEFAULT 0,
  needs_review  INTEGER NOT NULL DEFAULT 1,
  warnings      TEXT    NOT NULL DEFAULT '[]',
  raw_block     TEXT    NOT NULL DEFAULT ''
);

CREATE TABLE app_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE INDEX idx_questions_paper ON questions (paper_id, order_index);

Schema upgraded v1 → v2 → v3 via `ALTER TABLE` / `CREATE TABLE` migrations.
Deleting a paper cascades to its questions.

--------------------------------------------------------------------------------
7. WELCOME & LOGIN FLOW
--------------------------------------------------------------------------------

On first launch (or when `onboarding_complete` is not set), the app opens the
Welcome screen, then the Login screen:

- **WelcomeScreen** (`lib/ui/welcome_screen.dart`): Branded intro with app
  logo, name, tagline, and a "Get started" button that opens LoginScreen.
- **LoginScreen** (`lib/ui/login_screen.dart`): Email + password form with a
  demo credential pair (`demo@example.com` / `examvault123`). On success it
  marks `onboarding_complete` in `app_settings` and navigates to HomeScreen,
  removing all prior routes so the user can't back out to the login again.
- Subsequent launches skip straight to HomeScreen.

Routing is resolved in `lib/app.dart` (`ExamVaultApp`) by checking
`AppState.isOnboardingComplete()` at startup.

--------------------------------------------------------------------------------
8. HOME SCREEN & NAVIGATION DRAWER
--------------------------------------------------------------------------------

Home screen:
- Floating action button "Import paper" stays bottom-right (unchanged).
- "Your question bank" stats card (papers / questions / to review).
- "Top questions" section showing up to 10 questions grouped into category cards:
  History (3), Geography (3), Social Science (3), Maths (1).
- Each question row shows its number, text, section/marks, and taps through to
  the paper detail screen.
- Below, a compact "Your papers" list shows the most recent imported papers.
- Empty state prompts the user to import a PDF or TXT when there is no data.

Navigation drawer (hamburger icon, top-left of the app bar):
- Home, Calendar, About & help.
- Calendar section shows a minimal monthly grid (month navigation + today
  highlight) in a dedicated CalendarScreen.

--------------------------------------------------------------------------------
8. VERIFICATION RESULTS (after dependency setup)
--------------------------------------------------------------------------------

- flutter        : 3.50.0 (stable)  [INSTALLED]
- Android toolchain : [✓] SDK 36.0.0, cmdline-tools, licenses accepted
- Java           : 17.0.21 (OpenJDK)  [PRE-INSTALLED]
- Android Studio : /opt/android-studio  [PRE-INSTALLED]
- flutter pub get: dependencies resolved successfully
- flutter analyze: clean (no errors/warnings; only info-level deprecation
  notes for material.dart under Flutter 3.50)
- flutter test   : 24/24 tests passed

--------------------------------------------------------------------------------
8. KNOWN LIMITATIONS
--------------------------------------------------------------------------------

- No device/emulator testing performed in this environment; smoke-test on a
  real phone before distributing.
- Scanned PDFs are the least accurate path; OCR can misread characters (rows
  are flagged for review). Prefer the original digital PDF.
- Multi-column papers are read column by column; highly irregular layouts may
  need manual edits.
- Lower-case `(a)` items are treated as sub-parts, not MCQ options.
- Parser is heuristic, not an LLM; unusual numbering may split/merge questions.
- Release build is signed with Flutter's debug key; create a real keystore
  before Play Store publishing.
- syncfusion_flutter_pdf license terms apply for distribution.

================================================================================
                            END OF OVERVIEW
================================================================================
