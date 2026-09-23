// lib/core/parser/parsers/garanti_statement_parser.dart

import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';
import 'statement_parser.dart';

/// Garanti BBVA Paracard / Bonus hesap cetveli.
///
/// Tablo: İşlem Tarihi | Hesap No | Dönem İçi İşlemler | Bonus (TL) | Tutar (TL)
/// Banka işlemleri kendi sektör başlıkları altında gruplar ("Eczane", "Ulaşım", "GSM Shop"...);
/// bu başlıklar işlemin sektör etiketi olarak korunur. "NAKİT ÇEKİM İŞLEMLERİNİZ" bölümü nakit çekimdir.
class GarantiStatementParser implements LayoutStatementParser {
  static const _header = {'date': 'ISLEM TARIHI', 'desc': 'DONEM ICI ISLEMLER', 'amount': 'TUTAR'};
  static final RegExp _cardNo = RegExp(r'\d{4}\s?\d{2}\*{2}\s?\*{4}\s?\d{4}');

  @override
  ParserOutput parse(StatementLayout layout) {
    final records = <ParsedRecord>[];
    ColumnMap? cols;
    String card = '';
    String? sector;
    var kind = TransactionKind.purchase;

    for (final row in layout.rows) {
      final fold = TrStatementText.fold(row.text);
      if (fold.startsWith('KART NO')) {
        card = _cardNo.firstMatch(row.text)?.group(0) ?? card;
        continue;
      }
      final header = ColumnMap.fromHeader(row, _header, TrStatementText.fold);
      if (header != null) {
        cols = header;
        continue;
      }
      final c = cols;
      if (c == null || fold == 'BOSLUK') continue;

      if (fold.contains('NAKIT CEKIM ISLEMLERINIZ')) {
        kind = TransactionKind.cashAdvance;
        sector = 'Nakit Çekim';
        continue;
      }
      if (fold.contains('HARCAMALAR') && !TrStatementText.isDateCell(row.cells.first.text)) {
        kind = TransactionKind.purchase;
        sector = null;
        continue;
      }
      if (fold.startsWith('TOPLAM')) continue;

      final first = row.cells.first;
      final date = TrStatementText.isDateCell(first.text) ? TrStatementText.parseDate(first.text) : null;
      if (date == null) {
        // Tarihsiz tek hücreli satır: bankanın sektör başlığı ("Eczane", "Optik & Saat")
        if (row.cells.length == 1 && kind == TransactionKind.purchase) sector = first.text.trim();
        continue;
      }

      final amountCell = row.cells.lastWhere((x) => TrStatementText.isAmount(x.text), orElse: () => first);
      if (amountCell == first) continue;
      final description = row.cells
          .where((x) => x.left >= c['desc']! - 4 && x.right < amountCell.left && !TrStatementText.isAmount(x.text))
          .map((x) => x.text)
          .join(' ')
          .trim();
      final cents = TrStatementText.amountCents(amountCell.text)!;

      records.add(ParsedRecord(
        cardOrAccountMask: card,
        date: date,
        type: cents < 0 ? ParsedTransactionType.credit : ParsedTransactionType.debit,
        rawDescription: description,
        billingAmountCents: cents.abs(),
        kind: kind,
        sector: sector,
      ));
    }

    final purchases = TrStatementText.labelAmount(layout, ['Toplam Alışveriş Tutarınız']);
    final cash = TrStatementText.labelAmount(layout, ['Toplam Nakit Çekim Tutarınız']);
    return ParserOutput(
      records: records,
      accountIdentifier: card.isEmpty ? null : card,
      summary: StatementSummary(
        statementDate: TrStatementText.labelDate(layout, ['Hesap Kesim Tarihiniz', 'Hesap Kesim Tarihi']),
        dueDate: TrStatementText.labelDate(layout, ['Son Ödeme Tarihi']),
        statementBalanceCents: TrStatementText.labelAmount(layout, ['Dönem Borcu', 'Toplam Borç']),
        minimumPaymentCents: TrStatementText.labelAmount(layout, ['Asgari Ödeme Tutarı']),
        periodDebitsCents: (purchases == null && cash == null) ? null : (purchases ?? 0) + (cash ?? 0),
      ),
    );
  }
}
