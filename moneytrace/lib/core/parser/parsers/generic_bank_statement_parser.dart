// lib/core/parser/parsers/generic_bank_statement_parser.dart

import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';
import 'statement_parser.dart';
import 'table_block_reader.dart';

/// Özel parser'ı olmayan bankalar için genel hesap hareketi / kart ekstresi okuyucu.
///
/// Sayfadaki tablo başlığını (Tarih + Açıklama/İşlem + Tutar [+ Bakiye]) bulur, sütunları oradan ölçer
/// ve çok satırlı açıklamaları çapa eşlemeyle gruplar. İşaret: "-" gider, aksi halde
/// kredi kartında gider, vadesiz hesapta gelir kabul edilir ([isCardStatement]).
class GenericBankStatementParser implements LayoutStatementParser {
  final bool isCardStatement;
  const GenericBankStatementParser({this.isCardStatement = false});

  static const _dateLabels = ['ISLEM TARIHI', 'TARIH', 'ISLEM TAR'];
  static const _descLabels = ['ACIKLAMA', 'ISLEM ACIKLAMASI', 'ISLEMLER', 'ISLEM DETAYI', 'ISYERI', 'DONEM ICI ISLEMLER'];
  static const _amountLabels = ['TUTAR', 'ISLEM TUTARI', 'TUTAR(TL)', 'TUTAR (TL)'];
  static const _balanceLabels = ['BAKIYE', 'KALAN BAKIYE'];

  @override
  ParserOutput parse(StatementLayout layout) {
    final records = <ParsedRecord>[];
    ColumnMap? cols;
    var section = <LayoutRow>[];
    int? page;

    void flush() {
      final c = cols;
      if (c != null && section.isNotEmpty) {
        for (final b in TableBlockReader.read(section, c)) {
          final isExpense = b.signedAmountCents < 0 || (isCardStatement && !b.description.startsWith('+'));
          records.add(ParsedRecord(
            cardOrAccountMask: '',
            date: b.date,
            type: isExpense ? ParsedTransactionType.debit : ParsedTransactionType.credit,
            rawDescription: b.description,
            billingAmountCents: b.signedAmountCents.abs(),
            balanceAfterCents: b.balanceCents,
          ));
        }
      }
      section = [];
    }

    for (final row in layout.rows) {
      if (row.page != page) {
        flush();
        cols = null;
        page = row.page;
      }
      final header = _detectHeader(row);
      if (header != null) {
        flush();
        cols = header;
        continue;
      }
      final f = TrStatementText.fold(row.cells.first.text);
      if (f.startsWith('TOPLAM') || f.startsWith('SAYFA') || f.startsWith('DEVREDEN')) continue;
      if (cols != null) section.add(row);
    }
    flush();

    return ParserOutput(
      records: records,
      summary: StatementSummary(
        statementDate: TrStatementText.labelDate(layout, ['Hesap Kesim Tarihi', 'Ekstre Tarihi']),
        dueDate: TrStatementText.labelDate(layout, ['Son Ödeme Tarihi']),
        statementBalanceCents: TrStatementText.labelAmount(layout, ['Dönem Borcu', 'Toplam Borç', 'Dönem Sonu Bakiye']),
        minimumPaymentCents: TrStatementText.labelAmount(layout, ['Asgari Ödeme Tutarı', 'Asgari Tutar']),
        previousBalanceCents: TrStatementText.labelAmount(layout, ['Önceki Dönem Borcu', 'Dönem Başı Bakiye']),
      ),
    );
  }

  ColumnMap? _detectHeader(LayoutRow row) {
    double? find(List<String> labels) {
      for (final cell in row.cells) {
        final f = TrStatementText.fold(cell.text);
        if (labels.any((l) => f == l || f.startsWith('$l ') || f.startsWith('$l('))) return cell.left;
      }
      return null;
    }

    final date = find(_dateLabels);
    final desc = find(_descLabels);
    final amount = find(_amountLabels);
    if (date == null || desc == null || amount == null || !(date < desc && desc < amount)) return null;
    final balance = find(_balanceLabels);
    return ColumnMap({'date': date, 'desc': desc, 'amount': amount, if (balance != null) 'balance': balance});
  }
}
