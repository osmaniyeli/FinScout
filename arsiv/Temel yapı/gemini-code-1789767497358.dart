// DOSYA ADI: 15_PARSER_generic_payslip.dart
// HEDEF DİZİN: lib/features/statement_parser/parsers/15_PARSER_generic_payslip.dart

import '../models/parsed_models.dart';
import '../../../core/utils/currency_normalizer.dart';

class ParsedPayslipResult {
  final DateTime periodDate;
  final int grossSalaryCents;
  final int netSalaryCents;
  final int sgkWorkerCents;
  final int incomeTaxCents;
  final int stampTaxCents;
  final int? besDeductionCents;
  final List<ParsedTaxData> taxes;

  ParsedPayslipResult({
    required this.periodDate,
    required this.grossSalaryCents,
    required this.netSalaryCents,
    required this.sgkWorkerCents,
    required this.incomeTaxCents,
    required this.stampTaxCents,
    this.besDeductionCents,
    required this.taxes,
  });

  /// Bordroyu ana sisteme 'Gelir' (Net Maaş) ve 'Vergi Kesintileri' olarak dönüştürür.
  ParsedRecord toParsedRecord() {
    return ParsedRecord(
      cardOrAccountMask: 'BORDRO_GELIR',
      cardHolder: 'Çalışan Maaşı',
      date: periodDate,
      type: ParsedTransactionType.credit,
      rawDescription: 'Aylık Net Maaş Tahakkuku',
      billingAmountCents: netSalaryCents,
      taxes: taxes,
    );
  }
}

class GenericPayslipParser {
  // Regex Desenleri (Standart kurumsal ve e-Bordro şablonları için)
  static final RegExp _grossRegex = RegExp(r'(?:BRÜT\s*(?:ÜCRET|TUTAR|TOPLAM)|TOPLAM\s*KAZANÇ)[\s:]*([\d\.,]+)', caseSensitive: false);
  static final RegExp _netRegex = RegExp(r'(?:NET\s*(?:ÖDENEN|ÜCRET|TUTAR)|ÖDENECEK\s*NET)[\s:]*([\d\.,]+)', caseSensitive: false);
  static final RegExp _incomeTaxRegex = RegExp(r'(?:GELİR\s*VERGİSİ(?:\s*KESİNTİSİ)?)[\s:]*([\d\.,]+)', caseSensitive: false);
  static final RegExp _stampTaxRegex = RegExp(r'(?:DAMGA\s*VERGİSİ)[\s:]*([\d\.,]+)', caseSensitive: false);
  static final RegExp _sgkRegex = RegExp(r'(?:SGK\s*(?:İŞÇİ|PRİMİ)|S\.G\.K\.\s*KESİNTİSİ)[\s:]*([\d\.,]+)', caseSensitive: false);
  static final RegExp _besRegex = RegExp(r'(?:B\.E\.S\.|BES\s*KESİNTİSİ)[\s:]*([\d\.,]+)', caseSensitive: false);
  static final RegExp _periodRegex = RegExp(r'(\d{2})[/\.-](\d{4})|(\d{4})\s*(?:OCAK|ŞUBAT|MART|NİSAN|MAYIS|HAZİRAN|TEMMUZ|AĞUSTOS|EYLÜL|EKİM|KASIM|ARALIK)', caseSensitive: false);

  ParsedPayslipResult parse(String text) {
    final cleanText = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    // 1. Parasal Kalemlerin Tespiti
    final int gross = _extractCents(_grossRegex, cleanText);
    final int net = _extractCents(_netRegex, cleanText);
    final int incomeTax = _extractCents(_incomeTaxRegex, cleanText);
    final int stampTax = _extractCents(_stampTaxRegex, cleanText);
    final int sgk = _extractCents(_sgkRegex, cleanText);
    final int bes = _extractCents(_besRegex, cleanText);

    // 2. Dönem Tarihini Çıkar
    DateTime period = DateTime.now();
    final periodMatch = _periodRegex.firstMatch(cleanText);
    if (periodMatch != null) {
      if (periodMatch.group(1) != null && periodMatch.group(2) != null) {
        final m = int.tryParse(periodMatch.group(1)!) ?? period.month;
        final y = int.tryParse(periodMatch.group(2)!) ?? period.year;
        period = DateTime(y, m, 1);
      }
    }

    // 3. Vergi ve Kesinti Havuzunu Doldur
    final List<ParsedTaxData> taxes = [];
    if (incomeTax > 0) taxes.add(ParsedTaxData(taxType: 'INCOME_TAX', amountCents: incomeTax));
    if (stampTax > 0) taxes.add(ParsedTaxData(taxType: 'STAMP_TAX', amountCents: stampTax));
    if (sgk > 0) taxes.add(ParsedTaxData(taxType: 'SGK_WORKER', amountCents: sgk));

    return ParsedPayslipResult(
      periodDate: period,
      grossSalaryCents: gross,
      netSalaryCents: net > 0 ? net : (gross - incomeTax - stampTax - sgk - bes),
      sgkWorkerCents: sgk,
      incomeTaxCents: incomeTax,
      stampTaxCents: stampTax,
      besDeductionCents: bes > 0 ? bes : null,
      taxes: taxes,
    );
  }

  int _extractCents(RegExp regex, String source) {
    final match = regex.firstMatch(source);
    if (match != null && match.group(1) != null) {
      return CurrencyNormalizer.toMinorUnits(match.group(1)!).abs();
    }
    return 0;
  }
}