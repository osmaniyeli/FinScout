// lib/core/parser/parsers/yapikredi_card_parser.dart

import '../models/parsed_models.dart';
import '../../utils/currency_normalizer.dart';

class YapiKrediCardParser {
  // Kart Başlığı: "Kart Numarası: 4462 12****** 8281 ABDULLAH YEŞİLDEMİR"
  static final RegExp _cardHeaderRegex = RegExp(
    r'(?:Kart Numarası|Dijital Kart Numarası|Ek Kart Numarası)\s*:\s*([\d\* ]+)(?:\s+-\s*|\s+)?([A-ZÇĞİÖŞÜa-zçğıöşü ]+)?',
  );

  // Kredi Kartı Standart Harcama Satırı: "17 Mayıs 2026 WAT MOBİLİTE 1.250,50 12"
  static final RegExp _standardTxRegex = RegExp(
    r'^(\d{2}\s+[A-Za-zÇĞİÖŞÜçğıöşü]+\s+\d{4})\s+(.+?)\s+(\+?[\d\.,]+)(?:\s+(\d+))?$',
    multiLine: true,
  );

  // Taksit Detayı: "6.387,00 TL'lik işlemin 1/3 taksidi"
  static final RegExp _installmentRegex = RegExp(
    r"([\d\.,]+)\s*TL'lik işlemin\s*(\d+)/(\d+)\s*taksidi",
    caseSensitive: false,
  );

  // Yurt Dışı / Döviz Detayı: "İşlem Tutarı: 24,00 USD USD Karşılığı: 24,00 USD"
  static final RegExp _fxRegex = RegExp(
    r'İşlem Tutarı:\s*([\d\.,]+)\s*([A-Z]{3})\s*(?:USD Karşılığı\s*:\s*([\d\.,]+)\s*USD)?',
    caseSensitive: false,
  );

  static final Map<String, int> _months = {
    'ocak': 1, 'şubat': 2, 'mart': 3, 'nisan': 4, 'mayıs': 5, 'haziran': 6,
    'temmuz': 7, 'ağustos': 8, 'eylül': 9, 'ekim': 10, 'kasım': 11, 'aralık': 12,
  };

  List<ParsedRecord> parse(String text) {
    final List<ParsedRecord> records = [];
    final lines = text.split('\n');

    String currentCardMask = '4462 12****** 8281';
    String? currentCardHolder = 'Kart Sahibi';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 1. Kart Değişimi Tespiti (Asıl / Dijital / Ek Kart)
      final cardMatch = _cardHeaderRegex.firstMatch(line);
      if (cardMatch != null) {
        currentCardMask = cardMatch.group(1)!.trim();
        if (cardMatch.group(2) != null && cardMatch.group(2)!.trim().isNotEmpty) {
          currentCardHolder = cardMatch.group(2)!.trim();
        }
        continue;
      }

      // 2. Standart Harcama Satırı Eşleşmesi
      final txMatch = _standardTxRegex.firstMatch(line);
      if (txMatch != null) {
        final dateStr = txMatch.group(1)!;
        final desc = txMatch.group(2)!.trim();
        final amountStr = txMatch.group(3)!;

        // Tarih Çözümleme: '17 Mayıs 2026'
        final dateParts = dateStr.split(' ');
        final day = int.tryParse(dateParts[0]) ?? 1;
        final monthName = dateParts[1].toLowerCase();
        final month = _months[monthName] ?? 1;
        final year = int.tryParse(dateParts[2]) ?? 2026;
        final txDate = DateTime(year, month, day);

        final bool isCreditPayment = amountStr.startsWith('+');
        final billingCents = CurrencyNormalizer.toMinorUnits(amountStr).abs();

        ParsedInstallmentData? installment;
        int? origAmountCents;
        String? origCurrency;
        double? exchangeRate;

        // Bir sonraki satırlarda taksit veya döviz detayı var mı kontrol et
        int lookAhead = 1;
        while (i + lookAhead < lines.length) {
          final nextLine = lines[i + lookAhead].trim();
          if (nextLine.isEmpty) {
            lookAhead++;
            continue;
          }

          final instMatch = _installmentRegex.firstMatch(nextLine);
          final fxMatch = _fxRegex.firstMatch(nextLine);

          if (instMatch != null) {
            final totalInstCents = CurrencyNormalizer.toMinorUnits(instMatch.group(1)!);
            final currentInst = int.parse(instMatch.group(2)!);
            final totalInst = int.parse(instMatch.group(3)!);
            final remainingCents = totalInstCents - (billingCents * currentInst);

            installment = ParsedInstallmentData(
              currentInstallment: currentInst,
              totalInstallment: totalInst,
              remainingAmountCents: remainingCents > 0 ? remainingCents : 0,
              monthlyAmountCents: billingCents,
            );
            i += lookAhead;
            lookAhead = 1;
            continue;
          } else if (fxMatch != null) {
            origAmountCents = CurrencyNormalizer.toMinorUnits(fxMatch.group(1)!);
            origCurrency = fxMatch.group(2)?.toUpperCase();
            if (origAmountCents != null && origAmountCents > 0) {
              exchangeRate = billingCents / origAmountCents;
            }
            i += lookAhead;
            lookAhead = 1;
            continue;
          } else {
            break;
          }
        }

        records.add(ParsedRecord(
          cardOrAccountMask: currentCardMask,
          cardHolder: currentCardHolder,
          date: txDate,
          type: isCreditPayment ? ParsedTransactionType.credit : ParsedTransactionType.debit,
          rawDescription: desc,
          billingAmountCents: billingCents,
          originalAmountCents: origAmountCents,
          originalCurrency: origCurrency,
          exchangeRate: exchangeRate,
          installment: installment,
        ));
      }
    }

    return records;
  }
}
