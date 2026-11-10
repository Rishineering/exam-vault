import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../core/extraction/raw_document_builder.dart';
import '../core/models.dart';
import '../core/text/normalize.dart';

/// Renders each PDF page to an image and runs on-device ML Kit OCR.
///
/// Used only when a PDF has no usable embedded text layer (scanned papers or
/// papers exported as images).
class OcrExtractorService {
  const OcrExtractorService();

  Future<RawDocument> extract({
    required String fileName,
    required Uint8List bytes,
    String? filePath,
    void Function(int done, int total)? onProgress,
  }) async {
    final document = await pdfx.PdfDocument.openData(bytes);
    final recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    final tempDir = await getTemporaryDirectory();
    final pages = <PageLayout>[];

    try {
      final total = document.pagesCount;
      for (var i = 1; i <= total; i++) {
        final page = await document.getPage(i);
        pdfx.PdfPageImage? image;
        try {
          // Render at roughly 2x for reliable OCR of small exam text, but
          // cap the pixel width so memory stays bounded on low-end devices.
          final scale = (1800 / page.width).clamp(1.5, 3.0).toDouble();
          image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: pdfx.PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
        } finally {
          await page.close();
        }

        if (image == null) {
          onProgress?.call(i, total);
          continue;
        }

        final tempFile = File(
          p.join(tempDir.path, 'exam_vault_ocr_${DateTime.now().microsecondsSinceEpoch}_$i.png'),
        );
        await tempFile.writeAsBytes(image.bytes, flush: true);

        try {
          final input = InputImage.fromFilePath(tempFile.path);
          final recognized = await recognizer.processImage(input);
          final lines = <LayoutLine>[];
          for (final block in recognized.blocks) {
            for (final line in block.lines) {
              final text = normalizeInline(line.text);
              if (text.isEmpty) continue;
              final box = line.boundingBox;
              lines.add(LayoutLine(
                pageNumber: i,
                text: text,
                left: box.left,
                top: box.top,
                width: box.width,
                height: box.height,
              ));
            }
          }

          final width = (image.width ?? 0).toDouble();
          final height = (image.height ?? 0).toDouble();
          pages.add(PageLayout(
            pageNumber: i,
            width: width > 0 ? width : page.width * 2,
            height: height > 0 ? height : page.height * 2,
            lines: lines,
          ));
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }

        onProgress?.call(i, total);
      }

      return RawDocumentBuilder.fromPdfLines(
        fileName: fileName,
        filePath: filePath,
        method: ExtractionMethod.ocr,
        pages: pages,
      );
    } finally {
      await recognizer.close();
      await document.close();
    }
  }
}
