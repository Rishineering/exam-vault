# ExamVault

Turn previous-year exam question papers into a clean, editable question table —
**one question per row** — entirely on your Android device.

ExamVault reads a PDF (digital or scanned) or a plain-text file, extracts the
questions, and stores them in a local SQLite database that you can review,
correct and export to CSV. No account, no server, no network calls.

---

## Features

- **Import PDF or TXT** with the system file picker.
- **Digital PDFs**: reads the embedded text layer together with the position of
  every line, so headers, footers and two-column layouts can be handled.
- **Scanned PDFs**: renders pages and runs on-device OCR (ML Kit, Latin model
  bundled in the APK) when a PDF has no usable text layer.
- **Rule-based parser** detects:
  - question numbers — `1.`, `Q1.`, `1)`, `(1)`, `14(a)`, Roman numerals;
  - sections — `Section A`, `SECTION B`, `Part I`;
  - marks — `[2]`, `(2 marks)`, `3 M`;
  - MCQ options — uppercase `(A)`/`A)` and numeric `1)` forms.
- **Metadata** extraction: exam name, subject, year, class, duration, total marks.
- **Confidence score + review flag** per question, with a human-readable reason
  for every flag.
- **Review workflow**: search, filter (`All` / `Needs review` / `MCQ`), tap any
  row to edit the number, section, text, marks or options.
- **Paper management**: rename, view the raw extracted text, delete, export.
- **CSV export** through the Android share sheet (opens in Excel, Sheets, etc.).
- **Offline-first**: everything is stored in the app's private database.
- **Material 3** light/dark UI.

---

## Tech stack

| Concern            | Choice                                                    |
| ------------------ | --------------------------------------------------------- |
| Framework          | Flutter 3.47.9 / Dart 3.13.7                               |
| Target             | Android only (minSdk 24, targetSdk/compileSdk 36)          |
| PDF text layer     | `syncfusion_flutter_pdf` (layout-aware `TextLine.bounds`)  |
| Scanned-PDF render | `pdfx`                                                     |
| OCR                | `google_mlkit_text_recognition` (bundled Latin model)      |
| Storage            | `sqflite` (no code generation)                             |
| File picking       | `file_picker` 13                                           |
| Sharing/export     | `share_plus`                                               |
| Formatting         | `intl`                                                     |
| State              | plain `ChangeNotifier` + a small `InheritedNotifier` scope |

The extraction engine is **pure Dart** with no Flutter or plugin imports, so it
is fully unit-testable on a desktop VM.

---

## Project layout

```
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
test/                              Unit, service, widget and end-to-end tests
sample_exam_paper.txt              Sample input for the end-to-end test
```

---

## Extraction pipeline

```
file bytes
   │
   ├─ .txt ──────────────────────────────► decodeText (UTF-8 / UTF-16 / Latin-1)
   │
   └─ .pdf ──► embedded text layer? ──yes─► PdfTextExtractor (page + bounds)
                        │
                        └──no──────────────► pdfx render ► ML Kit OCR
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
```

A line that looks like a new question must satisfy the question-number rules;
four-digit years and lower-case `(a)` sub-parts are deliberately **not**
treated as new questions or MCQ options.

---

## Database schema (v1)

```sql
CREATE TABLE papers (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  title              TEXT    NOT NULL,
  file_name          TEXT    NOT NULL,
  source_type        TEXT    NOT NULL,   -- pdf | txt
  method             TEXT    NOT NULL,   -- embeddedText | ocr | plainText
  page_count         INTEGER NOT NULL,
  question_count     INTEGER NOT NULL,
  review_count       INTEGER NOT NULL,
  average_confidence REAL    NOT NULL,
  metadata_json      TEXT    NOT NULL,
  warnings_json      TEXT    NOT NULL,
  raw_text           TEXT    NOT NULL DEFAULT '',
  created_at         INTEGER NOT NULL
);

CREATE TABLE questions (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  paper_id      INTEGER NOT NULL REFERENCES papers(id) ON DELETE CASCADE,
  number        TEXT    NOT NULL,
  order_index   INTEGER NOT NULL,
  text          TEXT    NOT NULL,
  section       TEXT    NOT NULL DEFAULT '',
  marks         REAL,
  options_json  TEXT    NOT NULL,
  page_number   INTEGER NOT NULL,
  confidence    REAL    NOT NULL,
  needs_review  INTEGER NOT NULL,
  warnings_json TEXT    NOT NULL,
  raw_block     TEXT    NOT NULL DEFAULT ''
);
```

Deleting a paper cascades to its questions.

---

## Build and run

The project was built with a user-local, no-admin toolchain:

| Tool        | Location                          |
| ----------- | --------------------------------- |
| JDK 17      | `C:\Users\anand\dev\jdk17`        |
| Flutter     | `C:\Users\anand\dev\flutter`      |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk`      |
| Env script  | `C:\Users\anand\dev\env.ps1`      |

Load the environment first, then use Flutter normally:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
. C:\Users\anand\dev\env.ps1

flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Output: `build\app\outputs\flutter-apk\app-release.apk`

### Install on a phone

```powershell
adb install -r "C:\Users\anand\Documents\Default Project\ExamVault-release.apk"
```

Or copy the APK to the phone and open it (allow "install unknown apps").

> Pure-Dart helper scripts should use
> `& "$env:FLUTTER_ROOT\bin\cache\dart-sdk\bin\dart.exe"` — the `flutter\bin\dart`
> wrapper needs git, which is not installed here.

---

## Artifact

| Item        | Value                                                          |
| ----------- | -------------------------------------------------------------- |
| APK         | `C:\Users\anand\Documents\Default Project\ExamVault-release.apk` |
| Size        | 87,138,952 bytes (~83.1 MB)                                     |
| SHA256      | `42C921112C7F80041D4C4BFA2E70F59C62EE5E167F6171DF33CF37AA6B58A61B` |
| Package     | `com.examvault.exam_vault`                                      |
| Label       | ExamVault                                                       |
| minSdk      | 24 (Android 7.0)                                                |
| targetSdk   | 36                                                              |

The APK is a **universal** build. Most of the size is the bundled ML Kit OCR
model and native libraries. `flutter build apk --release --split-per-abi`
produces smaller per-architecture APKs if you prefer.

### Verification performed

- `flutter analyze` → **No issues found**
- `flutter test` → **24 tests passed**
  - 15 parser / layout / OCR tests
  - 6 text-decoding and CSV-escaping tests
  - 1 end-to-end sample-paper test
  - 2 question-table widget tests

---

## Limitations and notes

- **No device testing.** No Android device or emulator was available in the
  build environment. Install, OCR and SQLite behaviour were verified by
  analysis, unit/widget tests and a successful release build, but not on
  hardware. Please smoke-test on a real phone before distributing.
- **Scanned PDFs** are the least accurate path. OCR can misread characters;
  those rows are flagged for review. Prefer the original digital PDF.
- **Multi-column papers** are read column by column using line positions; highly
  irregular layouts (sidebars, overlapping boxes) may still need manual edits.
- **Lower-case `(a)` items** are treated as sub-parts of a question, not as MCQ
  options. Use uppercase `(A)` or numeric `1)` for options.
- **The parser is heuristic**, not an LLM. Unusual numbering schemes may split
  or merge questions; the review flag and manual editor exist for that reason.
- **Permissions.** The packaged manifest declares `INTERNET` and
  `ACCESS_NETWORK_STATE` because they are pulled in transitively by a Google
  library. The app itself makes no network requests.
- **Release signing.** The release build is currently signed with the Flutter
  template's **debug** key so it can be installed directly. Before publishing to
  Play Store, create a real keystore and a `signingConfigs.release` block in
  `android/app/build.gradle.kts`.
- **Licensing.** PDF text extraction uses `syncfusion_flutter_pdf`. No runtime
  license check was found in the package, but Syncfusion's community/commercial
  license terms apply for distribution. Review them before shipping
  commercially; `pdfx` + OCR could replace it if needed.

---

## Sample input

`sample_exam_paper.txt` contains a small two-section paper with marks and MCQ
options. The end-to-end test asserts that it produces 6 questions with the
correct metadata, sections, marks and options.
