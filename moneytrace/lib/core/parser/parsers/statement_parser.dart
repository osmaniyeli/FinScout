// lib/core/parser/parsers/statement_parser.dart

import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';

/// Bir banka parser'ının ham çıktısı: işlem satırları + başlıktaki banka beyanları.
/// Kategori, karşı taraf ve işlem türü zenginleştirmesi orkestratörde yapılır.
class ParserOutput {
  final List<ParsedRecord> records;
  final StatementSummary summary;
  final String? accountIdentifier;

  /// Hesap / kart sahibinin adı (kendi hesapları arası transferleri tanımak için)
  final String? accountHolder;

  const ParserOutput({
    required this.records,
    this.summary = StatementSummary.empty,
    this.accountIdentifier,
    this.accountHolder,
  });

  static const empty = ParserOutput(records: []);
}

/// Koordinat tabanlı düzen (StatementLayout) üzerinde çalışan parser sözleşmesi.
abstract class LayoutStatementParser {
  ParserOutput parse(StatementLayout layout);
}

/// Tablo başlık satırından türetilen sütun sınırları.
class ColumnMap {
  final Map<String, double> _left;
  const ColumnMap(this._left);

  double? operator [](String key) => _left[key];
  bool has(String key) => _left.containsKey(key);

  /// Başlık satırında verilen etiketlerin tamamı varsa sütun haritası döner.
  /// [labels]: anahtar → başlık hücresinin katlanmış (fold) metninin başladığı ifade.
  static ColumnMap? fromHeader(LayoutRow row, Map<String, String> labels, String Function(String) fold) {
    final found = <String, double>{};
    for (final entry in labels.entries) {
      for (final cell in row.cells) {
        if (fold(cell.text).startsWith(entry.value)) {
          found[entry.key] = cell.left;
          break;
        }
      }
    }
    return found.length == labels.length ? ColumnMap(found) : null;
  }
}
