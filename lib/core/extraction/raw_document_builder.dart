import '../models.dart';
import '../text/normalize.dart';

/// Builds [RawDocument] instances for sources that do not need a PDF engine.
class RawDocumentBuilder {
  const RawDocumentBuilder._();

  static RawDocument fromPlainText({
    required String fileName,
    required String text,
    String? filePath,
  }) {
    final normalized =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');
    final lines = <LayoutLine>[];

    for (var i = 0; i < rawLines.length; i++) {
      final value = normalizeInline(rawLines[i]);
      if (value.isEmpty) continue;
      lines.add(LayoutLine(
        pageNumber: 1,
        text: value,
        left: 0,
        top: i * 12.0,
        width: value.length * 5.0,
        height: 10,
      ));
    }

    return RawDocument(
      sourceType: SourceType.txt,
      method: ExtractionMethod.plainText,
      fileName: fileName,
      filePath: filePath,
      pages: [
        PageLayout(
          pageNumber: 1,
          width: 1000,
          height: rawLines.length * 12.0,
          lines: lines,
        ),
      ],
      rawText: lines.map((l) => l.text).join('\n'),
    );
  }

  /// Assembles a document from already-positioned lines (used by the PDF and
  /// OCR extractors).
  static RawDocument fromPdfLines({
    required String fileName,
    required String? filePath,
    required ExtractionMethod method,
    required List<PageLayout> pages,
  }) {
    final raw = <String>[];
    for (final page in pages) {
      for (final line in page.lines) {
        final value = normalizeInline(line.text);
        if (value.isNotEmpty) raw.add(value);
      }
    }
    return RawDocument(
      sourceType: SourceType.pdf,
      method: method,
      fileName: fileName,
      filePath: filePath,
      pages: pages,
      rawText: raw.join('\n'),
    );
  }
}
