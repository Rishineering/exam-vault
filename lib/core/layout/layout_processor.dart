import 'dart:math' as math;

import '../models.dart';
import '../parsing/patterns.dart';
import '../text/normalize.dart';

/// Turns positioned lines into a single, human reading-order sequence.
///
/// Two things make exam papers hard:
///  * headers / footers / page numbers are repeated and must not become
///    question text;
///  * many papers use a two-column layout, so sorting naively by `y` would
///    interleave the two columns and destroy question order.
class LayoutProcessor {
  const LayoutProcessor();

  List<LayoutLine> process(RawDocument doc) {
    if (doc.sourceType == SourceType.txt) {
      return [
        for (final page in doc.pages) ...page.lines,
      ];
    }

    final pages = _removeFurniture(doc);
    final ordered = <LayoutLine>[];
    for (final page in pages) {
      ordered.addAll(_orderPage(page));
    }
    return ordered;
  }

  // -------------------------------------------------------------------------
  // Header / footer / page-number removal
  // -------------------------------------------------------------------------

  List<PageLayout> _removeFurniture(RawDocument doc) {
    final pages = doc.pages;
    final pageCount = pages.length;

    // Count normalised versions of lines that sit in the top/bottom margins.
    // Using position (when available) is far safer than "first/last two
    // lines": a short page can have almost nothing but questions, and
    // digit-normalisation would make every numbered question look identical.
    final counts = <String, int>{};
    for (final page in pages) {
      for (final line in _furnitureCandidates(page)) {
        final key = normalizeForCompare(line.text);
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final threshold = math.max(2, (pageCount * 0.5).ceil());
    final repeated = counts.entries
        .where((e) =>
            pageCount >= 3 &&
            e.value >= threshold &&
            e.key.length <= 140)
        .map((e) => e.key)
        .toSet();

    final result = <PageLayout>[];
    for (final page in pages) {
      final nonEmpty =
          page.lines.where((l) => l.text.trim().isNotEmpty).toList();
      final total = nonEmpty.length;
      final kept = <LayoutLine>[];

      for (var i = 0; i < nonEmpty.length; i++) {
        final line = nonEmpty[i];
        final text = line.text.trim();
        final key = normalizeForCompare(text);

        final looksLikeQuestion = matchQuestionStart(text) != null &&
            (matchQuestionStart(text)?.remainder.length ?? 0) >= 8;
        if (!looksLikeQuestion && repeated.contains(key)) continue;

        final bool nearEdge;
        if (page.height > 0) {
          nearEdge = line.centerY <= page.height * 0.12 ||
              line.centerY >= page.height * 0.88;
        } else {
          nearEdge = i < 2 || i >= total - 2;
        }

        if (nearEdge && isPageNumberLine(text)) continue;

        kept.add(line);
      }

      result.add(PageLayout(
        pageNumber: page.pageNumber,
        width: page.width,
        height: page.height,
        lines: kept,
      ));
    }
    return result;
  }

  /// Lines that could plausibly be a running header or footer.
  List<LayoutLine> _furnitureCandidates(PageLayout page) {
    final nonEmpty = page.lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const [];

    if (page.height > 0) {
      return nonEmpty
          .where((l) =>
              l.centerY <= page.height * 0.12 ||
              l.centerY >= page.height * 0.88)
          .toList();
    }
    return <LayoutLine>[
      ...nonEmpty.take(2),
      ...nonEmpty.reversed.take(2),
    ];
  }

  // -------------------------------------------------------------------------
  // Reading order
  // -------------------------------------------------------------------------

  List<LayoutLine> _orderPage(PageLayout page) {
    final lines = page.lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (lines.length <= 1) return lines;

    lines.sort((a, b) {
      final byY = a.top.compareTo(b.top);
      return byY != 0 ? byY : a.left.compareTo(b.left);
    });

    final pageWidth = page.width > 0 ? page.width : 600.0;
    final fullWidthThreshold = pageWidth * 0.70;
    final separators =
        lines.where((l) => l.width >= fullWidthThreshold).toSet();

    // No full-width anchors: the page is either single-column or a clean
    // two-column layout. Let the gutter detector decide.
    if (separators.isEmpty) {
      return _orderBand(lines, pageWidth);
    }

    final output = <LayoutLine>[];
    var band = <LayoutLine>[];
    for (final line in lines) {
      if (separators.contains(line)) {
        output.addAll(_orderBand(band, pageWidth));
        band = <LayoutLine>[];
        output.add(line);
      } else {
        band.add(line);
      }
    }
    output.addAll(_orderBand(band, pageWidth));
    return output;
  }

  List<LayoutLine> _orderBand(List<LayoutLine> band, double pageWidth) {
    if (band.length < 4) return _sortByYThenX(band);

    final gutter = _findGutter(band, pageWidth);
    if (gutter == null) return _sortByYThenX(band);

    final left = <LayoutLine>[];
    final right = <LayoutLine>[];
    for (final line in band) {
      if (line.centerX < gutter) {
        left.add(line);
      } else {
        right.add(line);
      }
    }

    if (left.length < 2 || right.length < 2) return _sortByYThenX(band);

    // Both groups must occupy roughly the same vertical band; otherwise this
    // is not a real two-column layout.
    final leftTop = left.map((l) => l.top).reduce(math.min);
    final leftBottom = left.map((l) => l.bottom).reduce(math.max);
    final rightTop = right.map((l) => l.top).reduce(math.min);
    final rightBottom = right.map((l) => l.bottom).reduce(math.max);

    final overlap =
        math.min(leftBottom, rightBottom) - math.max(leftTop, rightTop);
    final minSpan = math.min(
      leftBottom - leftTop,
      rightBottom - rightTop,
    );
    if (minSpan <= 0 || overlap < minSpan * 0.4) {
      return _sortByYThenX(band);
    }

    return <LayoutLine>[
      ..._sortByYThenX(left),
      ..._sortByYThenX(right),
    ];
  }

  double? _findGutter(List<LayoutLine> band, double pageWidth) {
    double best = -1;
    var bestMin = 0;

    for (var x = pageWidth * 0.20;
        x <= pageWidth * 0.80;
        x += pageWidth / 160) {
      var left = 0;
      var right = 0;
      var crossing = 0;

      for (final line in band) {
        if (line.right <= x + 1) {
          left++;
        } else if (line.left >= x - 1) {
          right++;
        } else {
          crossing++;
        }
      }

      if (crossing == 0 && left >= 3 && right >= 3) {
        final smallest = math.min(left, right);
        if (smallest > bestMin) {
          bestMin = smallest;
          best = x;
        }
      }
    }

    return best < 0 ? null : best;
  }

  List<LayoutLine> _sortByYThenX(List<LayoutLine> lines) {
    final copy = List<LayoutLine>.from(lines);
    copy.sort((a, b) {
      final byY = a.top.compareTo(b.top);
      return byY != 0 ? byY : a.left.compareTo(b.left);
    });
    return copy;
  }
}
