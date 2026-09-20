// lib/core/parser/parsers/enpara_checking_parser.dart

import '../models/parsed_models.dart';
import '../../utils/currency_normalizer.dart';

class EnparaCheckingParser {
  // İşlem Satırı Yakalama Deseni: "28/07/26 BİM BİRLEŞİK MAĞAZALAR A.Ş. -456,50 TL 12.340,50 TL" veya "28/07/2026 PALGAZ Tüketim Faturası -450,00 TL"
  static final RegExp _txRowRegex = RegExp(
    r'^(\d{2}/\d{2}/\d{2,4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*TL(?:\s+([+-]?\s*[\d\.,]+)\s*TL)?\s*$',
    multiLine: true,
  );

  static final RegExp _fastQueryRegex = RegExp(r'sorgu no:\s*(\d+)', caseSensitive: false);
  static final RegExp _subscriberRegex = RegExp(r'abone no:\s*(\d+)', caseSensitive: false);
  static final RegExp _ibanHeaderRegex = RegExp(r'TR\d{2}\s?[0-9\s]{20,24}');

  List<ParsedRecord> parse(String text, {String? accountMask}) {
    final List<ParsedRecord> results = [];
    final matches = _txRowRegex.allMatches(text).toList();

    String effectiveAccountMask = accountMask ?? 'TR43 0015 **** 8065';
    final detectedIban = _ibanHeaderRegex.firstMatch(text);
    if (detectedIban != null && accountMask == null) {
      effectiveAccountMask = detectedIban.group(0)!.trim();
    }

    int i = 0;
    while (i < matches.length) {
      final match = matches[i];
      final dateStr = match.group(1)!;
      final desc = match.group(2)!.trim();
      final amountStr = match.group(3)!.replaceAll(' ', '');

      final dateParts = dateStr.split('/');
      int year = int.parse(dateParts[2]);
      if (year < 100) year += 2000;
      final date = DateTime(
        year,
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );

      final totalCents = CurrencyNormalizer.toMinorUnits(amountStr);
      final isDebit = totalCents < 0 || (!amountStr.startsWith('+') && (desc.toLowerCase().contains('fatura') || desc.toLowerCase().contains('palgaz') || desc.toLowerCase().contains('pos')));

      // FAST Sorgu No & Abone No Tespiti
      String? trackingId;
      final fastMatch = _fastQueryRegex.firstMatch(desc);
      if (fastMatch != null) {
        trackingId = 'FAST:${fastMatch.group(1)}';
      } else {
        final subMatch = _subscriberRegex.firstMatch(desc);
        if (subMatch != null) {
          trackingId = 'ABONE:${subMatch.group(1)}';
        }
      }

      // KREDİ TAKSİT KONSOLİDASYONU:
      // Aynı gün düşen Ana Para Taksiti, BSMV ve KKDF satırlarını tek bir işlem nesnesinde birleştirme
      final isLoanInstallment = (desc.toLowerCase().contains('kredi') || desc.toLowerCase().contains('ihtiyaç')) &&
          desc.toLowerCase().contains('taksiti') &&
          !desc.contains('BSMV') &&
          !desc.contains('KKDF');

      if (isLoanInstallment) {
        int consolidatedAmount = totalCents.abs();
        final List<ParsedTaxData> taxes = [];

        int lookAhead = 1;
        while (lookAhead <= 2 && (i + lookAhead) < matches.length) {
          final nextMatch = matches[i + lookAhead];
          final nextDesc = nextMatch.group(2)!;
          final nextAmountStr = nextMatch.group(3)!.replaceAll(' ', '');

          if (nextDesc.contains('BSMV')) {
            final bsmvCents = CurrencyNormalizer.toMinorUnits(nextAmountStr).abs();
            consolidatedAmount += bsmvCents;
            taxes.add(ParsedTaxData(taxType: 'BSMV', amountCents: bsmvCents));
            lookAhead++;
          } else if (nextDesc.contains('KKDF')) {
            final kkdfCents = CurrencyNormalizer.toMinorUnits(nextAmountStr).abs();
            consolidatedAmount += kkdfCents;
            taxes.add(ParsedTaxData(taxType: 'KKDF', amountCents: kkdfCents));
            lookAhead++;
          } else {
            break;
          }
        }

        results.add(ParsedRecord(
          cardOrAccountMask: effectiveAccountMask,
          cardHolder: 'Hesap Sahibi',
          date: date,
          type: ParsedTransactionType.debit,
          rawDescription: desc,
          billingAmountCents: consolidatedAmount,
          taxes: taxes,
          fastOrTrackingId: trackingId,
        ));

        i += lookAhead; // BSMV ve KKDF satırlarını konsolide ettik, atla
        continue;
      }

      results.add(ParsedRecord(
        cardOrAccountMask: effectiveAccountMask,
        cardHolder: 'Hesap Sahibi',
        date: date,
        type: isDebit ? ParsedTransactionType.debit : ParsedTransactionType.credit,
        rawDescription: desc,
        billingAmountCents: totalCents.abs(),
        fastOrTrackingId: trackingId,
      ));

      i++;
    }

    return results;
  }
}
