import '../models.dart';

/// Decides whether a PDF has enough embedded text to skip OCR.
class ExtractionQuality {
  const ExtractionQuality._();

  /// Scanned PDFs often expose only a handful of characters (or a few form
  /// fields) even though they render fine. If the embedded text is too sparse,
  /// the caller should fall back to OCR.
  static bool needsOcr(RawDocument doc) {
    if (doc.sourceType != SourceType.pdf) return false;
    if (doc.method == ExtractionMethod.ocr) return false;
    if (doc.pages.isEmpty) return true;

    if (doc.charactersPerPage < 40) return true;

    final text = doc.rawText;
    if (text.isEmpty) return true;

    final replacementCount = '\uFFFD'.allMatches(text).length;
    if (replacementCount / text.length > 0.02) return true;

    final letterCount = RegExp(r'[A-Za-z]').allMatches(text).length;
    if (letterCount / text.length < 0.15) return true;

    return false;
  }

  static bool hasUsableText(RawDocument doc) => doc.characterCount >= 20;
}
