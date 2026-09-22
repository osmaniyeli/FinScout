// lib/core/parser/parsers/akbank_statement_parser.dart

import '../models/parsed_models.dart';
import '../../utils/currency_normalizer.dart';

class AkbankStatementParser {
  static final RegExp _cardHeaderRegex = RegExp(
    r'(?:Kart No|Kart Numarası|Müşteri No|Hesap No)\s*:\s*([\d\* ]+)(?:\s+([A-ZÇĞİÖŞÜa-zçğıöşü ]+))?',
    caseSensitive: false,
  );

  static final RegExp _standardTxRegex = RegExp(
    r'^(\d{2}[./]\d{2}[./]\d{2,4})\s+(.+?)\s+([+-]?\s*[\d\.,]+)\s*(?:TL|TRY)?(?:\s+(.+))?$',
    multiLine: true,
  );

  static final RegExp _installmentRegex = RegExp(
    r'(?:(?:\(|\[)?(\d+)/(\d+)(?:\)|\])?\s*taksit|(?:\(|\[)(\d+)/(\d+)(?:\)|\])|taksit\s*:\s*(\d+)/(\d+))',
    caseSensitive: false,
  );

  List<ParsedRecord> parse(String text, {String? accountMask}) {
    final List<ParsedRecord> records = [];
    final lines = text.split('\n');

    String currentAccountMask = accountMask ?? 'TR.. 0046 **** ****';
    String? currentAccountHolder = 'Hesap Sahibi';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final headerMatch = _cardHeaderRegex.firstMatch(line);
      if (headerMatch != null) {
        currentAccountMask = headerMatch.group(1)!.trim();
        if (headerMatch.group(2) != null && headerMatch.group(2)!.trim().isNotEmpty) {
          currentAccountHolder = headerMatch.group(2)!.trim();
        }
        continue;
      }

      final txMatch = _standardTxRegex.firstMatch(line);
      if (txMatch != null) {
        final dateStr = txMatch.group(1)!;
        String desc = txMatch.group(2)!.trim();
        final amountStr = txMatch.group(3)!.replaceAll(' ', '');
        final trailingNote = txMatch.group(4)?.trim() ?? '';

        final lowerDesc = desc.toLowerCase();
        if (lowerDesc.contains('dönem borcu') ||
            lowerDesc.contains('asgari ödeme') ||
            lowerDesc.contains('hesap özeti') ||
            lowerDesc.contains('toplam borç')) {
          continue;
        }

        final sep = dateStr.contains('.') ? '.' : '/';
        final dateParts = dateStr.split(sep);
        final day = int.tryParse(dateParts[0]) ?? 1;
        final month = int.tryParse(dateParts[1]) ?? 1;
        int year = int.tryParse(dateParts[2]) ?? 2026;
        if (year < 100) year += 2000;
        final txDate = DateTime(year, month, day);

        final bool isCreditPayment = amountStr.startsWith('+') || lowerDesc.contains('ödeme') || lowerDesc.contains('iade');
        final billingCents = CurrencyNormalizer.toMinorUnits(amountStr).abs();
        if (billingCents <= 0) continue;

        ParsedInstallmentData? installment;
        final fullTextToCheck = '$desc $trailingNote';
        final instMatch = _installmentRegex.firstMatch(fullTextToCheck);
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
          cardOrAccountMask: currentAccountMask,
          cardHolder: currentAccountHolder,
          date: txDate,
          type: isCreditPayment ? ParsedTransactionType.credit : ParsedTransactionType.debit,
          rawDescription: desc,
          billingAmountCents: billingCents,
          installment: installment,
        ));
      }
    }

    return records;
  }
}
