// lib/core/parser/layout/statement_layout.dart

/// PDF motorundan gelen tek bir metin parçası (kelime veya kelime öbeği).
/// Koordinatlar PDF sayfa uzayındadır: y ekseni aşağıdan yukarı artar (top > bottom).
class RawTextFragment {
  final int page;
  final double left;
  final double right;
  final double top;
  final double bottom;
  final String text;

  const RawTextFragment({
    required this.page,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.text,
  });

  double get centerY => (top + bottom) / 2;
  double get height => (top - bottom).abs();
}

/// Görsel olarak birbirine yapışık kelimelerden oluşan hücre (tablo sütunu içeriği).
class LayoutCell {
  final double left;
  final double right;
  final String text;

  const LayoutCell({required this.left, required this.right, required this.text});

  double get center => (left + right) / 2;

  @override
  String toString() => '[${left.toStringAsFixed(0)}]$text';
}

/// Sayfadaki tek bir görsel satır; hücreler soldan sağa sıralıdır.
class LayoutRow {
  final int page;
  final double y;
  final List<LayoutCell> cells;

  const LayoutRow({required this.page, required this.y, required this.cells});

  /// Hücreler arasında iki boşlukla birleştirilmiş satır metni (sütun sınırları korunur).
  String get text => cells.map((c) => c.text).join('  ');

  /// [minLeft, maxLeft) aralığında başlayan hücrelerin metni.
  String textBetween(double minLeft, double maxLeft) => cells
      .where((c) => c.left >= minLeft && c.left < maxLeft)
      .map((c) => c.text)
      .join(' ')
      .trim();

  /// Verilen x konumunu kapsayan veya ona en yakın hücre ([tolerance] içinde).
  LayoutCell? cellNear(double x, {double tolerance = 40}) {
    LayoutCell? best;
    var bestDistance = double.infinity;
    for (final c in cells) {
      final distance = x < c.left
          ? c.left - x
          : (x > c.right ? x - c.right : 0.0);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = c;
      }
    }
    return bestDistance <= tolerance ? best : null;
  }

  @override
  String toString() => 'p$page y${y.toStringAsFixed(1)} | ${cells.join(' ')}';
}

/// PDF sayfalarının koordinat tabanlı yeniden kurulmuş satır/sütun yapısı.
/// Parser'lar ham metin yığını yerine bu yapıyı okur; böylece sütunlar (tarih, açıklama, tutar)
/// birbirine karışmaz.
class StatementLayout {
  final List<LayoutRow> rows;
  final int pageCount;

  const StatementLayout({required this.rows, required this.pageCount});

  /// Her görsel satır ayrı bir metin satırı olacak şekilde düz metin.
  String get plainText => rows.map((r) => r.text).join('\n');

  bool get isEmpty => rows.isEmpty;

  /// Aynı satırdaki iki kelime arasındaki bu mesafeden (pt) büyük boşluk yeni hücre başlatır.
  static const double _cellGap = 6.0;

  static StatementLayout fromFragments(List<RawTextFragment> fragments, {required int pageCount}) {
    final words = fragments.where((f) => f.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final byPage = a.page.compareTo(b.page);
        if (byPage != 0) return byPage;
        final byY = b.centerY.compareTo(a.centerY); // yukarıdan aşağıya
        if (byY != 0) return byY;
        return a.left.compareTo(b.left);
      });

    // 1. Dikey merkezleri yakın kelimeleri aynı satırda topla
    final rowBuckets = <List<RawTextFragment>>[];
    for (final w in words) {
      final current = rowBuckets.isEmpty ? null : rowBuckets.last;
      if (current != null && current.first.page == w.page) {
        final rowCenter = current.map((f) => f.centerY).reduce((a, b) => a + b) / current.length;
        final rowHeight = current.map((f) => f.height).reduce((a, b) => a > b ? a : b);
        final tolerance = (rowHeight * 0.45).clamp(1.5, 4.0);
        if ((w.centerY - rowCenter).abs() <= tolerance) {
          current.add(w);
          continue;
        }
      }
      rowBuckets.add([w]);
    }

    // 2. Satır içinde yatay boşluğa göre hücrelere ayır
    final rows = <LayoutRow>[];
    for (final bucket in rowBuckets) {
      bucket.sort((a, b) => a.left.compareTo(b.left));
      final cells = <LayoutCell>[];
      var cellLeft = bucket.first.left;
      var cellRight = bucket.first.right;
      final buffer = StringBuffer(bucket.first.text.trim());

      for (var i = 1; i < bucket.length; i++) {
        final w = bucket[i];
        if (w.left - cellRight > _cellGap) {
          cells.add(LayoutCell(left: cellLeft, right: cellRight, text: buffer.toString()));
          buffer.clear();
          cellLeft = w.left;
        } else {
          buffer.write(' ');
        }
        buffer.write(w.text.trim());
        if (w.right > cellRight) cellRight = w.right;
      }
      cells.add(LayoutCell(left: cellLeft, right: cellRight, text: buffer.toString()));

      final y = bucket.map((f) => f.centerY).reduce((a, b) => a + b) / bucket.length;
      rows.add(LayoutRow(page: bucket.first.page, y: y, cells: cells));
    }

    return StatementLayout(rows: rows, pageCount: pageCount);
  }
}
