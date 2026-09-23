// lib/core/parser/parsers/table_block_reader.dart

import '../layout/statement_layout.dart';
import '../util/tr_statement_text.dart';
import 'statement_parser.dart';

/// Tablodaki tek bir işlem bloğu: tarih + tutar (+ bakiye) + çok satırlı açıklama.
class TableBlock {
  final DateTime date;
  final int signedAmountCents;
  final int? balanceCents;
  final String description;

  const TableBlock({
    required this.date,
    required this.signedAmountCents,
    required this.balanceCents,
    required this.description,
  });
}

/// Çok satırlı açıklamalı hesap hareketi tablolarını "çapa eşleme" ile okur.
///
/// Her işlemin bir tarih hücresi ve bir tutar hücresi vardır; ikisi de bloğun dikey ortasında durur.
/// Tarih ve tutar çapaları sırayla eşlenir; açıklama satırları dikeyde en yakın bloğa bağlanır.
/// Böylece açıklamanın kaç satıra taştığından bağımsız doğru gruplama yapılır.
class TableBlockReader {
  /// [cols] şu anahtarları içermeli: `date`, `desc`, `amount`; isteğe bağlı `balance`.
  static List<TableBlock> read(List<LayoutRow> rows, ColumnMap cols, {double maxLineDistance = 24}) {
    final descLeft = cols['desc']!;
    final amountLeft = cols['amount']!;
    final balanceLeft = cols['balance'];

    final dates = <_Anchor<DateTime>>[];
    final amounts = <_Anchor<(int, int?)>>[];
    final lines = <_Anchor<String>>[];

    for (final row in rows) {
      final descParts = <String>[];
      int? amount;
      int? balance;
      for (final c in row.cells) {
        if (c.left < descLeft - 4 && TrStatementText.isDateCell(c.text)) {
          dates.add(_Anchor(row.y, TrStatementText.parseDate(c.text)!));
        } else if (balanceLeft != null && TrStatementText.isAmount(c.text) && c.right > balanceLeft - 10) {
          balance = TrStatementText.amountCents(c.text);
        } else if (TrStatementText.isAmount(c.text) && c.right > amountLeft - 80) {
          amount = TrStatementText.amountCents(c.text);
        } else if (c.left >= descLeft - 4) {
          descParts.add(c.text);
        }
      }
      if (amount != null) amounts.add(_Anchor(row.y, (amount, balance)));
      if (descParts.isNotEmpty) lines.add(_Anchor(row.y, descParts.join(' ')));
    }

    final count = dates.length < amounts.length ? dates.length : amounts.length;
    final blocks = List.generate(count, (i) => _Block(dates[i], amounts[i]));
    for (final line in lines) {
      _Block? nearest;
      var best = double.infinity;
      for (final b in blocks) {
        final d = (b.centerY - line.y).abs();
        if (d < best) {
          best = d;
          nearest = b;
        }
      }
      if (nearest != null && best <= maxLineDistance) nearest.lines.add(line);
    }

    return blocks.map((b) {
      b.lines.sort((a, c) => c.y.compareTo(a.y));
      final (amount, balance) = b.amount.value;
      return TableBlock(
        date: b.date.value,
        signedAmountCents: amount,
        balanceCents: balance,
        description: b.lines.map((l) => l.value).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
    }).toList();
  }
}

class _Anchor<T> {
  final double y;
  final T value;
  const _Anchor(this.y, this.value);
}

class _Block {
  final _Anchor<DateTime> date;
  final _Anchor<(int, int?)> amount;
  final List<_Anchor<String>> lines = [];
  _Block(this.date, this.amount);
  double get centerY => (date.y + amount.y) / 2;
}
