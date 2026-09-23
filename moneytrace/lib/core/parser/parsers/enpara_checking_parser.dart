// lib/core/parser/parsers/enpara_checking_parser.dart

import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';
import 'statement_parser.dart';
import 'table_block_reader.dart';

/// Enpara.com vadesiz hesap özeti.
///
/// Tablo: Tarih | Açıklama | Tutar | Bakiye. Açıklama 1-3 satıra yayılır; tarih ve tutar bloğun
/// dikey ortasında durur. Bu yüzden satır sırasına değil, çapa eşlemeye dayanır:
/// her işlemin bir tarih hücresi + bir tutar hücresi vardır; açıklama satırları en yakın çapaya bağlanır.
class EnparaCheckingParser implements LayoutStatementParser {
  static const _txHeader = {'date': 'TARIH', 'desc': 'ACIKLAMA', 'amount': 'TUTAR', 'balance': 'BAKIYE'};
  static const _orderHeader = {'date': 'TARIH', 'name': 'TALIMAT ADI', 'amount': 'TUTAR'};

  static final RegExp _iban = RegExp(r'TR\d{2}\s?\d{4}[\s*\d]{10,}\d{2}');
  static final RegExp _fastQuery = RegExp(r'sorgu no:\s*(\d+)', caseSensitive: false);

  @override
  ParserOutput parse(StatementLayout layout) {
    final records = <ParsedRecord>[];
    final scheduled = <ScheduledPayment>[];

    final ibanRow = layout.rows.where((r) => TrStatementText.fold(r.cells.first.text) == 'IBAN').firstOrNull;
    final iban = ibanRow == null ? null : _iban.firstMatch(ibanRow.text)?.group(0);

    // Sayfa sayfa, başlık ile bitiş arasındaki bölümleri topla
    var section = <LayoutRow>[];
    ColumnMap? txColumns;
    ColumnMap? orderColumns;

    void flush() {
      if (txColumns != null && section.isNotEmpty) {
        records.addAll(_parseTxSection(section, txColumns, iban ?? 'Enpara Vadesiz'));
      }
      if (orderColumns != null && section.isNotEmpty) {
        scheduled.addAll(_parseOrderSection(section, orderColumns));
      }
      section = [];
    }

    int? page;
    for (final row in layout.rows) {
      if (row.page != page) {
        flush();
        txColumns = null;
        orderColumns = null;
        page = row.page;
      }
      final tx = ColumnMap.fromHeader(row, _txHeader, TrStatementText.fold);
      if (tx != null) {
        flush();
        txColumns = tx;
        orderColumns = null;
        continue;
      }
      final order = ColumnMap.fromHeader(row, _orderHeader, TrStatementText.fold);
      if (order != null && !order.has('balance')) {
        flush();
        orderColumns = order;
        txColumns = null;
        continue;
      }
      final first = TrStatementText.fold(row.cells.first.text);
      if (first.startsWith('SAYFA') || first.startsWith('ENPARA BANK')) {
        flush();
        txColumns = null;
        orderColumns = null;
        continue;
      }
      // Talimat tablosu öncesi bilgilendirme paragrafı işlem tablosunu sonlandırır
      if (txColumns != null && row.cells.length == 1 && !TrStatementText.isAmount(row.cells.first.text) &&
          row.cells.first.left < txColumns['desc']! - 4 && TrStatementText.parseDate(row.text) == null) {
        flush();
        txColumns = null;
        continue;
      }
      section.add(row);
    }
    flush();

    return ParserOutput(
      records: records,
      accountIdentifier: iban,
      accountHolder: TrStatementText.labelValue(layout, ['Ad soyad']),
      summary: StatementSummary(
        previousBalanceCents: TrStatementText.labelAmount(layout, ['Dönem başı bakiyesi']),
        statementBalanceCents: TrStatementText.labelAmount(layout, ['Dönem sonu bakiyesi']),
        statementDate: _periodEnd(layout),
        scheduledPayments: scheduled,
      ),
    );
  }

  DateTime? _periodEnd(StatementLayout layout) {
    final period = TrStatementText.labelValue(layout, ['Ekstre dönemi']);
    if (period == null) return null;
    final parts = period.split('-');
    return parts.length == 2 ? TrStatementText.parseDate(parts[1]) : null;
  }

  List<ParsedRecord> _parseTxSection(List<LayoutRow> rows, ColumnMap cols, String account) {
    return TableBlockReader.read(rows, cols).map((b) {
      final classified = _classify(b.description, b.signedAmountCents);
      final amount = b.signedAmountCents.abs();
      return ParsedRecord(
        cardOrAccountMask: account,
        date: b.date,
        type: b.signedAmountCents < 0 ? ParsedTransactionType.debit : ParsedTransactionType.credit,
        rawDescription: b.description,
        billingAmountCents: amount,
        balanceAfterCents: b.balanceCents,
        kind: classified.kind,
        counterparty: classified.counterparty,
        taxes: classified.tax == null ? const [] : [ParsedTaxData(taxType: classified.tax!, amountCents: amount)],
        fastOrTrackingId: _fastQuery.firstMatch(b.description)?.group(1),
      );
    }).toList();
  }

  List<ScheduledPayment> _parseOrderSection(List<LayoutRow> rows, ColumnMap cols) {
    final result = <ScheduledPayment>[];
    DateTime? date;
    final desc = <String>[];
    for (final row in rows) {
      for (final c in row.cells) {
        if (TrStatementText.isDateCell(c.text) && c.left < cols['name']! - 4) {
          date = TrStatementText.parseDate(c.text);
        } else if (TrStatementText.isAmount(c.text) && c.left >= cols['amount']! - 60) {
          if (date != null) {
            result.add(ScheduledPayment(
              date: date,
              description: desc.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
              amountCents: TrStatementText.amountCents(c.text)!.abs(),
            ));
          }
          date = null;
          desc.clear();
        } else {
          desc.add(c.text);
        }
      }
    }
    return result;
  }

  /// Enpara açıklama kalıpları: "<Tür>, <karşı taraf>, <not>, EFT (FAST) sorgu no: …"
  _EnparaClass _classify(String description, int signedAmount) {
    final parts = description.split(',').map((p) => p.trim()).toList();
    final head = TrStatementText.fold(parts.first);
    final second = parts.length > 1 ? parts[1] : '';

    String posMerchant() {
      // "Diğer, 049800001118237-ONLY PARK BOWLING Kocaeli TR" → "ONLY PARK BOWLING"
      final m = RegExp(r'\d{5,}\s*-\s*(.+)').firstMatch(description);
      return (m?.group(1) ?? second).replaceAll(RegExp(r'\s+pos satış.*$', caseSensitive: false), '').trim();
    }

    if (head.startsWith('GIDEN TRANSFER')) return _EnparaClass(TransactionKind.transferOut, second);
    if (head.startsWith('GELEN TRANSFER')) return _EnparaClass(TransactionKind.transferIn, second);
    if (head.startsWith('IPTAL/IADE')) return _EnparaClass(TransactionKind.refund, posMerchant());
    if (head.startsWith('ENCARD HARCAMASI') || head.startsWith('DIGER')) {
      return _EnparaClass(TransactionKind.purchase, posMerchant());
    }
    if (head.startsWith('PARA CEKME')) return _EnparaClass(TransactionKind.cashAdvance, 'ATM');
    if (head.startsWith('PARA YATIRMA')) return _EnparaClass(TransactionKind.transferIn, 'ATM Para Yatırma');
    if (head.startsWith('VERGI KESINTISI')) {
      final fold = TrStatementText.fold(description);
      final tax = fold.contains('KKDF') ? 'KKDF' : (fold.contains('BSMV') ? 'BSMV' : 'OTHER_TAX');
      return _EnparaClass(TransactionKind.tax, 'Enpara', tax: tax);
    }
    if (head.startsWith('ODEME')) {
      final fold = TrStatementText.fold(description);
      if (fold.contains('KREDI') && fold.contains('TAKSIT')) {
        return _EnparaClass(TransactionKind.loanPayment, 'Enpara İhtiyaç Kredisi');
      }
      if (fold.contains('FATURA')) {
        return _EnparaClass(TransactionKind.billPayment, second.replaceAll(RegExp(r'\s*faturası.*', caseSensitive: false), ''));
      }
      return _EnparaClass(TransactionKind.other, second);
    }
    return _EnparaClass(signedAmount < 0 ? TransactionKind.other : TransactionKind.transferIn, second);
  }
}

class _EnparaClass {
  final TransactionKind kind;
  final String counterparty;
  final String? tax;
  const _EnparaClass(this.kind, this.counterparty, {this.tax});
}
