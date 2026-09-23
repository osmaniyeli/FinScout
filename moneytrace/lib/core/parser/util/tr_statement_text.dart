// lib/core/parser/util/tr_statement_text.dart

import '../../utils/currency_normalizer.dart';
import '../layout/statement_layout.dart';

/// Türk banka ekstrelerinde ortak kullanılan tutar / tarih / etiket ayrıştırma yardımcıları.
class TrStatementText {
  TrStatementText._();

  /// "1.234,56", "+8.091,04", "- 30.000,00 TL", "37,10"
  static final RegExp amountCell = RegExp(r'^([+-])?\s?(\d{1,3}(?:\.\d{3})*,\d{2})(?:\s?(?:TL|TRY))?$');

  /// Tutar hücresinden kuruş (işaret dahil). Tutar değilse null.
  static int? amountCents(String text) {
    final m = amountCell.firstMatch(text.trim());
    if (m == null) return null;
    final cents = CurrencyNormalizer.toMinorUnits(m.group(2)!);
    return m.group(1) == '-' ? -cents : cents;
  }

  static bool isAmount(String text) => amountCell.hasMatch(text.trim());

  static bool hasPlusSign(String text) => text.trim().startsWith('+');

  static const Map<String, int> _months = {
    'OCAK': 1, 'ŞUBAT': 2, 'SUBAT': 2, 'MART': 3, 'NİSAN': 4, 'NISAN': 4,
    'MAYIS': 5, 'HAZİRAN': 6, 'HAZIRAN': 6, 'TEMMUZ': 7, 'AĞUSTOS': 8, 'AGUSTOS': 8,
    'EYLÜL': 9, 'EYLUL': 9, 'EKİM': 10, 'EKIM': 10, 'KASIM': 11, 'ARALIK': 12,
  };

  static final RegExp _longDate = RegExp(r'^(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşü]+)\s+(\d{4})');
  static final RegExp _numericDate = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2}|\d{4})\b');

  /// "31 Ocak 2026", "06/02/26", "28/02/2026", "28.02.2026" → DateTime. Metnin başında arar.
  static DateTime? parseDate(String text) {
    final t = text.trim();
    final long = _longDate.firstMatch(t);
    if (long != null) {
      final month = _months[upper(long.group(2)!)];
      if (month == null) return null;
      return _safeDate(int.parse(long.group(3)!), month, int.parse(long.group(1)!));
    }
    final numeric = _numericDate.firstMatch(t);
    if (numeric != null) {
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      return _safeDate(year, int.parse(numeric.group(2)!), int.parse(numeric.group(1)!));
    }
    return null;
  }

  /// Metnin tamamı tarih mi (başında tarih olup devamında başka şey olmayan hücre)
  static bool isDateCell(String text) {
    final t = text.trim();
    final long = _longDate.firstMatch(t);
    if (long != null) return long.group(0)!.length == t.length && parseDate(t) != null;
    final numeric = _numericDate.firstMatch(t);
    return numeric != null && numeric.group(0)!.length == t.length;
  }

  static DateTime? _safeDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m ? date : null;
  }

  /// Türkçe büyük harf dönüşümü (i → İ, ı → I)
  static String upper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  /// Karşılaştırma için sadeleştirme: Türkçe harfler ASCII'ye, büyük harf, tek boşluk.
  static String fold(String s) => upper(s)
      .replaceAll('İ', 'I')
      .replaceAll('Ş', 'S')
      .replaceAll('Ğ', 'G')
      .replaceAll('Ü', 'U')
      .replaceAll('Ö', 'O')
      .replaceAll('Ç', 'C')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// "Etiket : Değer" satırlarından değeri bulur. Etiket karşılaştırması harf/boşluk duyarsızdır.
  /// Değer, etiketten sonra gelen ilk ':' hücresinden sonraki hücredir (sağdaki adres blokları karışmaz).
  static String? labelValue(StatementLayout layout, List<String> labels) {
    final wanted = labels.map(fold).toList();
    for (final row in layout.rows) {
      if (row.cells.isEmpty) continue;
      for (var i = 0; i < row.cells.length; i++) {
        final label = fold(row.cells[i].text.replaceAll(':', ''));
        if (!wanted.contains(label)) continue;
        // Değer aynı hücrede ':' sonrasında olabilir ("Tarih: 12.01.2026")
        final inline = row.cells[i].text.split(':');
        if (inline.length > 1 && inline.sublist(1).join(':').trim().isNotEmpty) {
          return inline.sublist(1).join(':').trim();
        }
        for (var j = i + 1; j < row.cells.length; j++) {
          final v = row.cells[j].text.trim();
          if (v == ':' || v.isEmpty) continue;
          return v.startsWith(':') ? v.substring(1).trim() : v;
        }
      }
    }
    return null;
  }

  static int? labelAmount(StatementLayout layout, List<String> labels) {
    final v = labelValue(layout, labels);
    if (v == null) return null;
    final m = RegExp(r'[+-]?\s?\d{1,3}(?:\.\d{3})*,\d{2}').firstMatch(v);
    return m == null ? null : amountCents(m.group(0)!);
  }

  static DateTime? labelDate(StatementLayout layout, List<String> labels) {
    final v = labelValue(layout, labels);
    return v == null ? null : parseDate(v);
  }
}
