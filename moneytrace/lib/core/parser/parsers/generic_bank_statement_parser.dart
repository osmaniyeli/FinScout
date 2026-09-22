// lib/core/parser/parsers/generic_bank_statement_parser.dart

import '../models/parsed_models.dart';
import '../../utils/currency_normalizer.dart';

/// Tüm Türk bankaları (Ziraat, Halkbank, VakıfBank, QNB, TEB, DenizBank vb.) için
/// yüksek hata toleranslı, evrensel ekstre ve hesap özeti ayrıştırıcı motoru.
class GenericBankStatementParser {
  // Çoklu formatlı tarih ve harcama yakalama
  // Örnekler:
  // "12.08.2026 SHELL PETROL 1.500,00 TL"
  // "12/08/2026 MİGROS TİCARET -450,50 TL 1.250,00 TL"
  // "12.08.2026 MAAS TAHAKKUK +45.000,00 TL"
  static final RegExp _universalTxRegex = RegExp(
    r'^(\d{2}[./-]\d{2}[./-]\d{2,4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*(?:TL|TRY)?(?:\s+(.+))?$',
    multiLine: true,
  );

  // Taksit Deseni
  static final RegExp _installmentRegex = RegExp(
    r'(?:(?:\(|\[)?(\d+)/(\d+)(?:\)|\])?\s*taksit|(?:\(|\[)(\d+)/(\d+)(?:\)|\])|taksit\s*:\s*(\d+)/(\d+))',
    caseSensitive: false,
  );

  // IBAN veya Kart No başlığı
  static final RegExp _accountIdentifierRegex = RegExp(
    r'(?:TR\d{2}\s?[0-9\s]{20,24}|\b(?:\d{4}[ -]?\d{2}\*{2}[ -]?\*{4}[ -]?\d{4})\b)',
  );

  List<ParsedRecord> parse(String text, {String? defaultMask, String? institutionName}) {
    final List<ParsedRecord> records = [];
    final lines = text.split('\n');

    String effectiveMask = defaultMask ?? 'TR.. **** **** ****';
    final detectedId = _accountIdentifierRegex.firstMatch(text);
    if (detectedId != null && defaultMask == null) {
      effectiveMask = detectedId.group(0)!.trim();
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final match = _universalTxRegex.firstMatch(line);
      if (match != null) {
        final dateStr = match.group(1)!;
        String desc = match.group(2)!.trim();
        final amountStr = match.group(3)!.replaceAll(' ', '');
        final trailing = match.group(4)?.trim() ?? '';

        final lowerDesc = desc.toLowerCase();
        // Finansal özet veya sayfa başlığı filtreleri
        if (lowerDesc.contains('dönem borcu') ||
            lowerDesc.contains('asgari ödeme') ||
            lowerDesc.contains('hesap özeti') ||
            lowerDesc.contains('toplam limit') ||
            lowerDesc.contains('kullanılabilir limit') ||
            lowerDesc.contains('ekstre tarihi') ||
            lowerDesc.contains('son ödeme')) {
          continue;
        }

        // Tarih parse
        String sep = '.';
        if (dateStr.contains('/')) sep = '/';
        if (dateStr.contains('-')) sep = '-';
        final parts = dateStr.split(sep);
        if (parts.length < 3) continue;

        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        int year = int.tryParse(parts[2]) ?? 2026;
        if (year < 100) year += 2000;
        final txDate = DateTime(year, month, day);

        final bool isCredit = amountStr.startsWith('+') || lowerDesc.contains('ödeme') || lowerDesc.contains('iade') || lowerDesc.contains('alacak');
        final billingCents = CurrencyNormalizer.toMinorUnits(amountStr).abs();
        if (billingCents <= 0) continue;

        // Taksit kontrolü
        ParsedInstallmentData? installment;
        final checkText = '$desc $trailing';
        final instMatch = _installmentRegex.firstMatch(checkText);
        if (instMatch != null) {
          final currInst = int.tryParse(instMatch.group(1) ?? instMatch.group(3) ?? instMatch.group(5) ?? '1') ?? 1;
          final totalInst = int.tryParse(instMatch.group(2) ?? instMatch.group(4) ?? instMatch.group(6) ?? '1') ?? 1;

          if (totalInst > 1) {
            final remainingMonths = totalInst - currInst;
            installment = ParsedInstallmentData(
              currentInstallment: currInst,
              totalInstallment: totalInst,
              remainingAmountCents: remainingMonths * billingCents,
              monthlyAmountCents: billingCents,
            );
          }
        }

        records.add(ParsedRecord(
          cardOrAccountMask: effectiveMask,
          cardHolder: institutionName ?? 'Hesap Sahibi',
          date: txDate,
          type: isCredit ? ParsedTransactionType.credit : ParsedTransactionType.debit,
          rawDescription: desc,
          billingAmountCents: billingCents,
          installment: installment,
        ));
      }
    }

    return records;
  }
}
