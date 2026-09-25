// lib/core/parser/enpara_checking_parser.dart

import 'models/parsed_models.dart';
import '../utils/currency_normalizer.dart';

class EnparaCheckingParser {
  static final RegExp _txRowRegex = RegExp(
    r'^(\d{2}/\d{2}/\d{2})\s+(.+?)\s+(-?\s*[\d\.,]+)\s*TL\s+([\d\.,]+)\s*TL$',
    multiLine: true,
  );

  static final RegExp _loanInstallmentRegex = RegExp(
    r'(\d+)\.\s*taksiti(?:\s*(BSMV|KKDF))?',
  );

  static final RegExp _fastQueryRegex = RegExp(r'sorgu no:\s*(\d+)');

  List<ParsedRecord> parse(String text) {
    final List<ParsedRecord> results = [];
    final matches = _txRowRegex.allMatches(text).toList();

    int i = 0;
    while (i < matches.length) {
      final match = matches[i];
      final dateStr = match.group(1)!;
      final desc = match.group(2)!.trim();
      final amountStr = match.group(3)!.replaceAll(' ', '');

      final dateParts = dateStr.split('/');
      final date = DateTime(
        2000 + int.parse(dateParts[2]),
        int.parse(dateParts[1]),
        int.parse(dateParts[0]),
      );

      final totalCents = CurrencyNormalizer.toMinorUnits(amountStr);
      final isDebit = totalCents < 0;

      // FAST Sorgu No Tespiti
      String? fastId;
      final fastMatch = _fastQueryRegex.firstMatch(desc);
      if (fastMatch != null) {
        fastId = fastMatch.group(1);
      }

      // KREDİ TAKSİT KONSOLİDASYONU: Taksit + BSMV + KKDF satırlarını birleştirme
      if (desc.contains('ihtiyaç kredinizin') && !desc.contains('BSMV') && !desc.contains('KKDF')) {
        int consolidatedAmount = totalCents.abs();
        final List<ParsedTaxData> taxes = [];

        // Sonraki 2 satırı kontrol et (BSMV ve KKDF)
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
          cardOrAccountMask: 'TR43 0015 **** 8065',
          date: date,
          type: ParsedTransactionType.debit,
          rawDescription: desc,
          billingAmountCents: consolidatedAmount,
          taxes: taxes,
          fastOrTrackingId: fastId,
        ));

        i += lookAhead; // BSMV ve KKDF satırlarını atla
        continue;
      }

      results.add(ParsedRecord(
        cardOrAccountMask: 'TR43 0015 **** 8065',
        date: date,
        type: isDebit ? ParsedTransactionType.debit : ParsedTransactionType.credit,
        rawDescription: desc,
        billingAmountCents: totalCents.abs(),
        fastOrTrackingId: fastId,
      ));

      i++;
    }

    return results;
  }
}