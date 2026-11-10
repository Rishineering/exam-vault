import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../core/extraction/raw_document_builder.dart';
import '../core/models.dart';
import '../core/text/normalize.dart';

/// Extracts positioned text lines from a PDF that already contains an
/// embedded text layer (i.e. a "digital" PDF).
///
/// Scanned PDFs produce little or no text here; callers should check
/// [ExtractionQuality.needsOcr] and fall back to OCR.
class PdfTextExtractorService {
  const PdfTextExtractorService();

  RawDocument extract({
    required String fileName,
    required Uint8List bytes,
    String? filePath,
  }) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final pageCount = document.pages.count;
      if (pageCount == 0) {
        return RawDocumentBuilder.fromPdfLines(
          fileName: fileName,
          filePath: filePath,
          method: ExtractionMethod.embeddedText,
          pages: const <PageLayout>[],
        );
      }
      final pages = <PageLayout>[];

      for (var i = 0; i < pageCount; i++) {
        final size = document.pages[i].size;
        pages.add(PageLayout(
          pageNumber: i + 1,
          width: size.width,
          height: size.height,
          lines: <LayoutLine>[],
        ));
      }

      final extracted = PdfTextExtractor(document).extractTextLines();
      final seen = <String>{};

      for (final line in extracted) {
        final text = normalizeInline(line.text);
        if (text.isEmpty) continue;

        final index = line.pageIndex.clamp(0, pageCount - 1);
        final bounds = line.bounds;
        final key =
            '${text.toLowerCase()}|${bounds.left.round()}|${bounds.top.round()}';
        if (!seen.add(key)) continue;

        pages[index].lines.add(LayoutLine(
          pageNumber: index + 1,
          text: text,
          left: bounds.left,
          top: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ));
      }

      final merged = <PageLayout>[
        for (final page in pages)
          PageLayout(
            pageNumber: page.pageNumber,
            width: _pageWidth(page),
            height: _pageHeight(page),
            lines: _mergeFragments(page.lines),
          ),
      ];

      return RawDocumentBuilder.fromPdfLines(
        fileName: fileName,
        filePath: filePath,
        method: ExtractionMethod.embeddedText,
        pages: merged,
      );
    } finally {
      document.dispose();
    }
  }

  double _pageWidth(PageLayout page) {
    if (page.width > 0) return page.width;
    var maxRight = 0.0;
    for (final line in page.lines) {
      if (line.right > maxRight) maxRight = line.right;
    }
    return maxRight <= 0 ? 595 : maxRight;
  }

  double _pageHeight(PageLayout page) {
    if (page.height > 0) return page.height;
    var maxBottom = 0.0;
    for (final line in page.lines) {
      if (line.bottom > maxBottom) maxBottom = line.bottom;
    }
    return maxBottom <= 0 ? 842 : maxBottom;
  }

  /// Some PDF generators emit a visual line as several fragments (e.g. one
  /// per tab stop or font run). Re-join fragments that sit on the same
  /// baseline with only a small horizontal gap. Fragments in different
  /// columns are separated by a large gap and are therefore left alone.
  List<LayoutLine> _mergeFragments(List<LayoutLine> input) {
    if (input.length < 2) return input;

    final sorted = List<LayoutLine>.from(input)
      ..sort((a, b) {
        final byY = a.top.compareTo(b.top);
        return byY != 0 ? byY : a.left.compareTo(b.left);
      });

    final output = <LayoutLine>[];
    for (final line in sorted) {
      if (output.isEmpty) {
        output.add(line);
        continue;
      }
      final previous = output.last;
      final sameBaseline =
          (line.centerY - previous.centerY).abs() <=
              (previous.height.clamp(4, 40) * 0.55);
      final gap = line.left - previous.right;
      final smallGap = gap >= -2 && gap <= 28;

      if (sameBaseline && smallGap) {
        output[output.length - 1] = LayoutLine(
          pageNumber: previous.pageNumber,
          text: joinWrapped(previous.text, line.text),
          left: previous.left,
          top: previous.top,
          width: (line.right - previous.left).clamp(previous.width, 10000),
          height: previous.height > line.height ? previous.height : line.height,
        );
      } else {
        output.add(line);
      }
    }
    return output;
  }
}
