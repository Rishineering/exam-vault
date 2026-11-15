import 'package:flutter/widgets.dart';

import '../app.dart';

/// Lightweight English / Hindi strings used by the app shell and the
/// study-feature screens.
///
/// The language comes from the user's exam profile (`en`, `hi` or `bilingual`).
/// Bilingual profiles see Hindi labels with the English name kept alongside
/// where it is useful.
class AppText {
  const AppText(this.language);

  /// `en`, `hi` or `bilingual`.
  final String language;

  bool get isHindi => language == 'hi' || language == 'bilingual';

  /// Reads the language chosen in the user's profile without rebuilding.
  static AppText read(BuildContext context) {
    final profile = AppScope.read(context).userProfile;
    return AppText(profile?.language ?? 'en');
  }

  /// Reads the language and subscribes the caller to profile changes.
  static AppText of(BuildContext context) {
    final profile = AppScope.of(context).userProfile;
    return AppText(profile?.language ?? 'en');
  }

  String pick(String english, String hindi) => isHindi ? hindi : english;

  // --- App shell -----------------------------------------------------------
  String get appName => 'SetYourRank';
  String get tagline => pick('Question papers made simple', 'प्रश्नपत्र अब आसान');
  String get home => pick('Home', 'होम');
  String get calendar => pick('Calendar', 'कैलेंडर');
  String get syllabusTracker => pick('Syllabus Tracker', 'सिलेबस ट्रैकर');
  String get pyqExplorer => pick('PYQ Explorer', 'पिछले वर्ष के प्रश्न');
  String get mockTests => pick('Mock Tests', 'मॉक टेस्ट');
  String get analytics => pick('Analytics', 'विश्लेषण');
  String get revisionQueue => pick('Revision Queue', 'रिवीज़न कतार');
  String get bookmarks => pick('Bookmarks', 'बुकमार्क');
  String get profile => pick('Profile', 'प्रोफ़ाइल');
  String get aboutHelp => pick('About & help', 'परिचय और सहायता');
  String get explanations => pick('Explanations', 'व्याख्या');

  // --- Shared --------------------------------------------------------------
  String get english => 'English';
  String get hindi => 'हिन्दी';
  String get languageLabel => pick('Language', 'भाषा');
  String get languageHint => pick(
        'Choose the language used across the app.',
        'ऐप में इस्तेमाल होने वाली भाषा चुनें।',
      );
  String get languageSaved => pick('Language updated', 'भाषा अपडेट हो गई');
  String get save => pick('Save', 'सहेजें');
  String get cancel => pick('Cancel', 'रद्द करें');
  String get close => pick('Close', 'बंद करें');
  String get edit => pick('Edit', 'संपादित करें');
  String get delete => pick('Delete', 'हटाएँ');
  String get search => pick('Search…', 'खोजें…');
  String get sourceLabel => pick('Source', 'स्रोत');
  String get questionLabel => pick('Question', 'प्रश्न');

  // --- Explanations --------------------------------------------------------
  String get answerExplanations => pick('Answer Explanations', 'उत्तर व्याख्या');
  String get explanationsSubtitle => pick(
        'Every question that has a saved explanation.',
        'हर वह प्रश्न जिसकी व्याख्या सहेजी गई है।',
      );
  String get noExplanationsTitle => pick('No explanations yet', 'अभी कोई व्याख्या नहीं');
  String get noExplanationsBody => pick(
        'Open a question from any paper and add an explanation in the edit '
        'sheet. It will appear here.',
        'किसी भी पेपर से प्रश्न खोलें और संपादन शीट में व्याख्या जोड़ें। '
        'वह यहाँ दिखाई देगी।',
      );
  String get searchExplanationsHint =>
      pick('Search explanations…', 'व्याख्या खोजें…');
  String get editExplanation => pick('Edit explanation', 'व्याख्या संपादित करें');
  String get explanationSaved => pick('Explanation saved', 'व्याख्या सहेजी गई');
  String get explanationRequired =>
      pick('Please write an explanation first.', 'कृपया पहले व्याख्या लिखें।');
  String get deleteExplanationBody => pick(
        'Delete this explanation? This cannot be undone.',
        'यह व्याख्या हटाएँ? इसे वापस नहीं लाया जा सकता।',
      );
  String get explanationLanguage =>
      pick('Explanation language', 'व्याख्या की भाषा');
  String get addExplanation => pick('Add explanation', 'व्याख्या जोड़ें');

  // --- Bookmarks -----------------------------------------------------------
  String get noBookmarksTitle => pick('No bookmarks yet', 'अभी कोई बुकमार्क नहीं');
  String get noBookmarksBody => pick(
        'Tap the bookmark icon on any question to save it here.',
        'किसी भी प्रश्न पर बुकमार्क आइकन दबाकर उसे यहाँ सहेजें।',
      );
  String get bookmarkedLabel => pick('Bookmarked', 'बुकमार्क किया गया');
  String get bookmarkedToday => pick('Bookmarked today', 'आज बुकमार्क किया');
  String get bookmarkedYesterday =>
      pick('Bookmarked yesterday', 'कल बुकमार्क किया');
  String bookmarkedDaysAgo(int days) => pick(
        'Bookmarked $days days ago',
        '$days दिन पहले बुकमार्क किया',
      );
  String get openPaper => pick('Open in paper', 'पेपर में खोलें');
  String get bookmark => pick('Bookmark', 'बुकमार्क करें');
  String get removeBookmark => pick('Remove bookmark', 'बुकमार्क हटाएँ');
  String get explanationAvailable =>
      pick('Explanation available', 'व्याख्या उपलब्ध है');

  // --- Revision queue ------------------------------------------------------
  String get noRevisionsTitle => pick('No revisions due', 'कोई रिवीज़न बाकी नहीं');
  String get noRevisionsBody => pick(
        'Questions you add to revision will appear here on their due date.',
        'रिवीज़न में जोड़े गए प्रश्न उनकी नियत तिथि पर यहाँ दिखेंगे।',
      );
  String get revisionDueToday => pick('Due today', 'आज देय');
  String get revisionOverdue => pick('Overdue', 'अतिदेय');
  String get revisionTomorrow => pick('Due tomorrow', 'कल देय');
  String revisionInDays(int days) =>
      pick('Due in $days days', '$days दिनों में देय');
  String revisionInterval(int days) => pick(
        'Interval: $days day${days == 1 ? '' : 's'}',
        'अंतराल: $days दिन',
      );
  String get markCorrect => pick('I remembered it', 'मुझे याद था');
  String get markIncorrect => pick('Needs review again', 'फिर दोहराना है');
  String get revisionUpdated => pick('Revision scheduled', 'रिवीज़न निर्धारित');

  String get addToRevision =>
      pick('Add to revision queue', 'रिवीज़न कतार में जोड़ें');
  String get addToRevisionHint => pick(
        'Schedule this question for spaced repetition today.',
        'इस प्रश्न को आज से दोहराने के लिए निर्धारित करें।',
      );
  String get addedToRevision =>
      pick('Added to revision queue', 'रिवीज़न कतार में जोड़ा गया');

  // --- PYQ explorer --------------------------------------------------------
  String get pyqNoResults => pick('No PYQ questions found', 'कोई पुराना प्रश्न नहीं मिला');
  String get pyqNoResultsBody => pick(
        'Import papers with previous-year questions, or mark questions as PYQ '
        'from the edit sheet.',
        'पिछले वर्ष के प्रश्न वाले पेपर आयात करें, या संपादन शीट से प्रश्नों को '
        'PYQ के रूप में चिह्नित करें।',
      );
  String get year => pick('Year', 'वर्ष');
  String get difficulty => pick('Difficulty', 'कठिनाई');
  String get all => pick('All', 'सभी');
  String get easy => pick('Easy', 'आसान');
  String get medium => pick('Medium', 'मध्यम');
  String get hard => pick('Hard', 'कठिन');
  String get searchQuestionsHint => pick('Search questions…', 'प्रश्न खोजें…');
  String pyqCount(int count) => pick(
        '$count PYQ question${count == 1 ? '' : 's'}',
        '$count पुराने प्रश्न',
      );

  // --- Difficulty / importance labels -------------------------------------
  String difficultyLabel(String value) {
    switch (value.toLowerCase()) {
      case 'easy':
        return easy;
      case 'hard':
        return hard;
      default:
        return medium;
    }
  }

  // --- Analytics -----------------------------------------------------------
  String get performanceAnalytics =>
      pick('Performance Analytics', 'प्रदर्शन विश्लेषण');
  String get overview => pick('Overview', 'अवलोकन');
  String get overallAccuracy => pick('Overall Accuracy', 'कुल सटीकता');
  String get totalAttempts => pick('Total Attempts', 'कुल प्रयास');
  String get studyTime => pick('Study Time', 'अध्ययन समय');
  String get accuracyBySubject =>
      pick('Accuracy by Subject', 'विषयवार सटीकता');
  String get weakAreasTitle =>
      pick('Weak Areas (Needs Attention)', 'कमज़ोर क्षेत्र (ध्यान दें)');
  String get studyTimeTrend =>
      pick('Study Time & Accuracy Trend', 'अध्ययन समय और सटीकता का रुझान');
  String get noStudyDataYet => pick(
        'Take a mock test to see your 7-day study trend.',
        '7-दिवसीय रुझान देखने के लिए एक मॉक टेस्ट दें।',
      );
  String get last7Days => pick('Last 7 Days', 'पिछले 7 दिन');
  String get minutesShort => pick('m', 'मि.');
  String get hoursShort => pick('h', 'घं.');

  // --- Mock Test & Review ---------------------------------------------------
  String get createMockTest => pick('Create Mock Test', 'मॉक टेस्ट बनाएँ');
  String get testConfiguration =>
      pick('Test Configuration', 'टेस्ट विन्यास');
  String get testTitle => pick('Test Title', 'टेस्ट का शीर्षक');
  String get allSubjects => pick('All Subjects', 'सभी विषय');
  String get allDifficulties => pick('All Difficulties', 'सभी कठिनाई स्तर');
  String get pyqOnlyToggle =>
      pick('Previous Year Questions only', 'केवल पिछले वर्षों के प्रश्न');
  String get pyqOnlySubtitle => pick(
        'Include only questions marked as PYQ',
        'केवल PYQ चिह्नित प्रश्नों को शामिल करें',
      );
  String get numberOfQuestions =>
      pick('Number of Questions', 'प्रश्नों की संख्या');
  String get durationMinutes => pick('Duration (minutes)', 'समय (मिनट)');
  String get startTest => pick('Start Test', 'टेस्ट शुरू करें');
  String get testResults => pick('Test Results', 'टेस्ट परिणाम');
  String get testCompleted => pick('Test Completed', 'टेस्ट पूरा हुआ');
  String scoreSummary(int score, int total) => pick(
        'You scored $score out of $total',
        'आपने $total में से $score अंक प्राप्त किए',
      );
  String get correct => pick('Correct', 'सही');
  String get wrong => pick('Wrong', 'गलत');
  String get accuracy => pick('Accuracy', 'सटीकता');
  String get timeTaken => pick('Time Taken', 'लिया गया समय');
  String get backToHome => pick('Back to Home', 'होम पर वापस');
  String get questionReview =>
      pick('Question-by-Question Review', 'प्रश्न-वार समीक्षा');
  String get yourAnswer => pick('Your answer', 'आपका उत्तर');
  String get correctAnswer => pick('Correct answer', 'सही उत्तर');
  String get notAnswered => pick('Not answered', 'अनुत्तरित');
  String get filterAll => pick('All', 'सभी');
  String get filterCorrect => pick('Correct', 'सही');
  String get filterIncorrect => pick('Incorrect', 'गलत');
  String get solutionExplanation =>
      pick('Solution & Explanation', 'हल और व्याख्या');

  // --- Syllabus Tracker -----------------------------------------------------
  String get overallProgress => pick('Overall Progress', 'कुल प्रगति');
  String get addSubject => pick('Add Subject', 'विषय जोड़ें');
  String get addTopic =>
      pick('Add Topic', 'विषय-वस्तु (Topic) जोड़ें');
  String get subjectName => pick('Subject Name', 'विषय का नाम');
  String get topicName => pick('Topic Name', 'टॉपिक का नाम');
  String get noSubjectsTitle =>
      pick('No subjects added yet', 'अभी तक कोई विषय नहीं जोड़ा गया');
  String get noSubjectsBody => pick(
        'Add subjects from your syllabus to track your progress.',
        'अपनी प्रगति ट्रैक करने के लिए पाठ्यक्रम से विषय जोड़ें।',
      );
  String get markCompleted => pick('Completed', 'पूर्ण');
  String get inProgress => pick('In progress', 'प्रगति पर');
}
