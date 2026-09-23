// lib/core/parser/parsers/yapikredi_card_parser.dart

import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';
import 'statement_parser.dart';

/// Yapı Kredi (World / KoçAilem / Adios vb.) kredi kartı hesap özeti.
///
/// Tablo: İşlem Tarihi | İşlemler | Tutar(TL) | Kalan Tutar/Taksit | Puan
/// Devam satırları: "3.207,78 TL'lik işlemin 1 / 3 taksidi", "İşlem Tutarı: 24,00 USD"
class YapiKrediCardParser implements LayoutStatementParser {
  static const _headerLabels = {
    'date': 'ISLEM TARIHI',
    'desc': 'ISLEMLER',
    'amount': 'TUTAR(TL)',
    'remaining': 'KALAN TUTAR',
  };

  static final RegExp _cardHeader = RegExp(
    r'^(?:(?:Dijital|Ek|Sanal)\s+)?Kart\s+Numaras[ıi]',
    caseSensitive: false,
  );
  static final RegExp _installmentDetail = RegExp(
    r"([\d.,]+)\s*TL'lik\s+işlemin\s+(\d+)\s*/\s*(\d+)\s*taksidi",
    caseSensitive: false,
  );
  static final RegExp _fxDetail = RegExp(
    r'İşlem\s+Tutarı\s*:\s*([\d.,]+)\s*([A-Z]{3})(?:\s+USD\s+Karşılığı\s*:\s*([\d.,]+)\s*USD)?',
    caseSensitive: false,
  );
  static final RegExp _remainingCell = RegExp(r'^([\d.,]+)\s*/\s*(\d+)$');
  static final RegExp _cardMask = RegExp(r'\d{4,6}\s?[\d*]{2}\*{0,2}\s?\*{2,4}\s?\*{0,4}\s?\d{4}');

  @override
  ParserOutput parse(StatementLayout layout) {
    final records = <ParsedRecord>[];
    ColumnMap? columns;
    String cardMask = '';
    String? cardHolder;
    String? firstCardMask;

    for (final row in layout.rows) {
      final first = row.cells.first.text;

      // 1. Kart değişimi (asıl / dijital / ek kart)
      if (_cardHeader.hasMatch(first)) {
        final mask = _cardMask.firstMatch(row.text);
        if (mask != null) {
          cardMask = mask.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
          firstCardMask ??= cardMask;
          final holderCell = row.cells.last.text;
          if (!_cardMask.hasMatch(holderCell)) cardHolder = holderCell;
        }
        continue;
      }

      // 2. Tablo başlığı (her sayfada tekrar eder; sütunları yeniden ölç)
      final header = ColumnMap.fromHeader(row, _headerLabels, TrStatementText.fold);
      if (header != null) {
        columns = header;
        continue;
      }
      final cols = columns;
      if (cols == null) continue;

      final dateCell = row.cells
          .where((c) => c.left >= cols['date']! - 8 && c.left < cols['desc']! - 2)
          .firstOrNull;
      final date = dateCell != null && TrStatementText.isDateCell(dateCell.text)
          ? TrStatementText.parseDate(dateCell.text)
          : null;

      // 3. Tarihsiz satır → önceki işlemin devam satırı (taksit / döviz detayı)
      if (date == null) {
        if (records.isNotEmpty) {
          final updated = _applyContinuation(records.last, row.text);
          if (updated != null) records[records.length - 1] = updated;
        }
        continue;
      }

      // 4. İşlem satırı: tutar, "Tutar(TL)" sütununun sağa yaslı hücresidir
      final amountCell = _findAmountCell(row, cols);
      if (amountCell == null) continue;

      final description = row.cells
          .where((c) => c.left >= cols['desc']! - 4 && c.right <= amountCell.left + 1 && c != amountCell)
          .map((c) => c.text)
          .join('  ')
          .trim();
      if (description.isEmpty) continue;

      final cents = TrStatementText.amountCents(amountCell.text)!;
      final isCredit = TrStatementText.hasPlusSign(amountCell.text) || cents < 0;

      ParsedInstallmentData? installment;
      final remaining = row.cells
          .where((c) => c.left > amountCell.right)
          .map((c) => _remainingCell.firstMatch(c.text))
          .whereType<RegExpMatch>()
          .firstOrNull;
      if (remaining != null) {
        installment = ParsedInstallmentData(
          currentInstallment: 0, // devam satırından doldurulur
          totalInstallment: 0,
          remainingAmountCents: TrStatementText.amountCents(remaining.group(1)!) ?? 0,
          monthlyAmountCents: cents.abs(),
        );
      }

      records.add(ParsedRecord(
        cardOrAccountMask: cardMask,
        cardHolder: cardHolder,
        date: date,
        type: isCredit ? ParsedTransactionType.credit : ParsedTransactionType.debit,
        rawDescription: description,
        billingAmountCents: cents.abs(),
        installment: installment,
      ));
    }

    return ParserOutput(
      records: records,
      accountIdentifier: firstCardMask,
      accountHolder: cardHolder,
      summary: _parseSummary(layout),
    );
  }

  LayoutCell? _findAmountCell(LayoutRow row, ColumnMap columns) {
    final amountLeft = columns['amount']!;
    final remainingLeft = columns['remaining']!;
    // Tutar sütunu sağa yaslıdır: hücrenin sağ kenarı "Tutar(TL)" başlığı ile "Kalan" başlığı arasında biter
    for (final c in row.cells) {
      if (!TrStatementText.isAmount(c.text)) continue;
      if (c.right >= amountLeft - 60 && c.right <= remainingLeft + 4) return c;
    }
    return null;
  }

  ParsedRecord? _applyContinuation(ParsedRecord last, String text) {
    final inst = _installmentDetail.firstMatch(text);
    if (inst != null) {
      final total = TrStatementText.amountCents(inst.group(1)!) ?? 0;
      final current = int.parse(inst.group(2)!);
      final count = int.parse(inst.group(3)!);
      final monthly = last.billingAmountCents;
      return last.copyWith(
        installment: ParsedInstallmentData(
          currentInstallment: current,
          totalInstallment: count,
          remainingAmountCents:
              last.installment?.remainingAmountCents ?? (total - monthly * current).clamp(0, total),
          monthlyAmountCents: monthly,
        ),
      );
    }
    final fx = _fxDetail.firstMatch(text);
    if (fx != null) {
      final currency = fx.group(2)!.toUpperCase();
      final usd = fx.group(3);
      // "İşlem Tutarı: 159,99 TRY USD Karşılığı: 3,65 USD" → TL ile ödenmiş yurt dışı işyeri
      final isLocalPriced = currency == 'TRY' && usd != null;
      final origCents = TrStatementText.amountCents(isLocalPriced ? usd : fx.group(1)!);
      if (origCents == null || origCents == 0) return null;
      return last.copyWith(
        originalAmountCents: origCents,
        originalCurrency: isLocalPriced ? 'USD' : currency,
        exchangeRate: last.billingAmountCents / origCents,
      );
    }
    return null;
  }

  StatementSummary _parseSummary(StatementLayout layout) {
    int? amount(List<String> labels) => TrStatementText.labelAmount(layout, labels);
    DateTime? date(List<String> labels) => TrStatementText.labelDate(layout, labels);

    return StatementSummary(
      statementDate: date(['Hesap Kesim Tarihi']),
      dueDate: date(['Son Ödeme Tarihi']),
      statementBalanceCents: amount(['Dönem Borcu']),
      minimumPaymentCents: amount(['Ödenmesi Gereken Asgari Tutar/Oranı', 'Ödenmesi Gereken Asgari Tutar/Oran', 'Asgari Ödeme Tutarı']),
      previousBalanceCents: amount(['Önceki Dönem Hesap Özeti Borcu']),
      periodDebitsCents: amount(['Dönem İçi Harcamalar']),
      periodCreditsCents: amount(['Dönem İçi Ödemeler'])?.abs(),
      creditLimitCents: amount(['Kart Limiti']),
      nextStatementDate: date(['Bir Sonraki Ay Hesap Kesim Tarihi']),
      nextDueDate: date(['Bir Sonraki Ay Son Ödeme Tarihi']),
    );
  }
}
