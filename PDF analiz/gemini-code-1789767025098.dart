// lib/core/parser/yapikredi_card_parser.dart

import 'models/parsed_models.dart';
import '../utils/currency_normalizer.dart';

class YapiKrediCardParser {
  static final RegExp _cardHeaderRegex = RegExp(
    r'(?:Kart Numarası|Dijital Kart Numarası)\s*:\s*([\d\* ]+)(?:\s+([A-ZÇĞİÖŞÜ ]+))?',
  );

  static final RegExp _standardTxRegex = RegExp(
    r'^(\d{2}\s+[A-Za-zÇĞİÖŞÜçğıöşü]+\s+\d{4})\s+(.+?)\s+(\+?[\d\.,]+)(?:\s+(\d+))?$',
    multiLine: true,
  );

  static final RegExp _installmentRegex = RegExp(
    r"([\d\.,]+)\s*TL'lik işlemin\s*(\d+)/(\d+)\s*taksidi",
  );

  static final RegExp _fxRegex = RegExp(
    r'İşlem Tutarı:\s*([\d\.,]+)\s*([A-Z]{3})\s*USD Karşılığı\s*:\s*([\d\.,]+)\s*USD',
  );

  static final Map<String, int> _months = {
    'Ocak': 1, 'Şubat': 2, 'Mart': 3, 'Nisan': 4, 'Mayıs': 5, 'Haziran': 6,
    'Temmuz': 7, 'Ağustos': 8, 'Eylül': 9, 'Ekim': 10, 'Kasım': 11, 'Aralık': 12
  };

  List<ParsedRecord> parse(String text) {
    final List<ParsedRecord> records = [];
    final lines = text.split('\n');

    String currentCardMask = '4462 12****** 8281';
    String? currentCardHolder = 'ABDULLAH YEŞİLDEMİR';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Kart Değişimi Tespiti (Asıl / Dijital / Ek Kart)
      final cardMatch = _cardHeaderRegex.firstMatch(line);
      if (cardMatch != null) {
        currentCardMask = cardMatch.group(1)!.trim();
        if (cardMatch.group(2) != null) {
          currentCardHolder = cardMatch.group(2)!.trim();
        }
        continue;
      }

      // Standart Harcama Satırı Eşleşmesi
      final txMatch = _standardTxRegex.firstMatch(line);
      if (txMatch != null) {
        final dateStr = txMatch.group(1)!;
        String desc = txMatch.group(2)!.trim();
        final amountStr = txMatch.group(3)!;

        // Tarih Çözümleme: '17 Mayıs 2026'
        final dateParts = dateStr.split(' ');
        final day = int.parse(dateParts[0]);
        final month = _months[dateParts[1]] ?? 1;
        final year = int.parse(dateParts[2]);
        final txDate = DateTime(year, month, day);

        final bool isCreditPayment = amountStr.startsWith('+');
        final billingCents = CurrencyNormalizer.toMinorUnits(amountStr).abs();

        ParsedInstallmentData? installment;
        int? origAmountCents;
        String? origCurrency;

        // Bir sonraki satırda taksit veya döviz detayı var mı kontrol et
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();

          // Taksit Detayı: "6.387,00 TL'lik işlemin 1/3 taksidi"
          final instMatch = _installmentRegex.firstMatch(nextLine);
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
            i++; // Taksit satırını tüket
          }

          // Yurt Dışı Döviz Detayı: "İşlem Tutarı: 24,00 USD USD Karşılığı: 24,00 USD"
          final fxMatch = _fxRegex.firstMatch(nextLine);
          if (fxMatch != null) {
            origAmountCents = CurrencyNormalizer.toMinorUnits(fxMatch.group(1)!);
            origCurrency = fxMatch.group(2);
            i++; // FX satırını tüket
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
          installment: installment,
        ));
      }
    }

    return records;
  }
}