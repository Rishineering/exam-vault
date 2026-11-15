# ExamVault Development Progress

## Batch 3 — completed

1. **Answer Explanations catalogue**
   - New `ExplanationsScreen` (drawer → Explanations) lists every saved
     explanation joined with its real question.
   - English / Hindi filter, text search, full-detail dialog, edit and delete.
   - Question edit sheet now pre-fills the existing explanation for the
     selected language instead of starting blank.

2. **Hindi language support**
   - New `lib/core/app_strings.dart` (`AppText`) with English + Hindi labels.
   - Language comes from the exam profile (`en`, `hi`, `bilingual`).
   - Localised: hamburger drawer, Explanations, Bookmarks, Revision Queue,
     PYQ Explorer (filters, empty states, difficulty labels).
   - Language switch added to About & help → Language card, saved to the
     profile and applied immediately.

3. **QA polish**
   - **PYQ Explorer now loads real data** (question is PYQ-flagged or has an
     exam year, falling back to the paper's year). Year/difficulty/search
     filters work; empty state explains how to add PYQs.
   - **Bookmarks** now show the actual question, bookmark date and open the
     source paper; unbookmark from the list.
   - **Revision Queue** shows the real question, due state and interval;
     "remembered" doubles the interval, "again" resets it to 1 day.
   - Added "Add to revision queue" toggle to the question edit sheet so the
     queue can be populated.
   - **Syllabus coverage** no longer uses the placeholder loop: coverage is
     computed from questions answered in attempts.
   - **Mock tests now use stored questions** (objective only) instead of
     generated questions with invalid ids, fixing foreign-key failures when
     saving attempt answers.
   - **Answer keys**: schema v6 adds `correct_option` to `questions` and
     `generated_questions`; seeded sample MCQs carry keys; the edit sheet can
     set/clear the correct option; mock tests score against it.
   - Submitting a mock test now updates the existing attempt instead of
     inserting a duplicate; wrong answers are added to the revision queue.
   - Cleaned all analyzer warnings (only deprecation infos remain).
   - Empty states are pull-to-refresh friendly.

## Verification
- `flutter analyze`: 0 errors / 0 warnings (41 deprecation infos)
- `flutter test`: 28/28 passed (added AppText localisation tests)
- `flutter build apk --debug`: built successfully

## Known limitations / next batch candidates
- Answer keys are only present on seeded sample MCQs; imported papers need a
  key set from the edit sheet before mock scoring is accurate.
- Analytics "Study Time Trend" chart is still a placeholder.
- LLM generation pipeline still waits for the user's API key.
- Imported subjective questions are excluded from timed mock tests.

## Notes
- Database schema is now v6. Existing installs migrate automatically; seeded
  rows created before v6 will have no answer key until edited (clear app data
  to re-seed the sample bank with keys).
- No new pub dependencies were added.
- All features remain in the existing hamburger drawer.

## Batch 1 — completed (for reference)
1. Subject & Syllabus Coverage Tracker
2. PYQ Explorer
3. Timed Mock Tests & Practice Mode
4. Supporting: exam profiles, analytics, explanations, difficulty tagging,
   bookmarking (schema v5 + base screens).

## Batch 2 — completed (for reference)
1. Answer explanations in the question edit sheet
2. Bookmarks screen + bookmark toggle in question rows
3. Revision queue screen with spaced-repetition controls
