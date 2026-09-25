// lib/core/parser/parsers/generic_payslip_parser.dart

import '../layout/statement_layout.dart';
import '../models/parsed_models.dart';
import '../util/tr_statement_text.dart';
import 'statement_parser.dart';

/// Ücret bordrosu (SGK standardı: Brüt Ödemeler / Yasal Kesintiler / Net Ödenen).
/// Net maaş gelir kaydı olarak, yasal kesintiler vergi kalemleri olarak döner.
class GenericPayslipParser implements LayoutStatementParser {
  static final RegExp _monthYear = RegExp(
    r'^(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık)\s+(\d{4})$',
    caseSensitive: false,
  );

  /// Belgenin bordro olup olmadığını düzenden anlar (kelime "bordro" geçmeyebilir).
  static bool looksLikePayslip(String text) {
    final f = TrStatementText.fold(text);
    final hasNet = f.contains('NET ODENEN') || f.contains('NET UCRET') || f.contains('ELE GECEN');
    final hasDeductions = f.contains('YASAL KESINTI') || f.contains('SGK') || f.contains('SSK KESINTISI');
    final hasGross = f.contains('BRUT');
    return hasNet && hasDeductions && hasGross;
  }

  /// Etiket hücresi bazen önceki sütunun sayısıyla birleşir ("178,50 SSK Kesintisi"). Önce tam eşleşme,
  /// yoksa "sayı + etiket" biçimindeki hücrede etiketin hemen sağındaki tutar okunur.
  static int? _looseAmount(StatementLayout layout, List<String> labels) {
    final exact = TrStatementText.labelAmount(layout, labels);
    if (exact != null) return exact;
    final wanted = labels.map(TrStatementText.fold).toList();
    final amountRe = RegExp(r'^[+-]?\s?\d{1,3}(?:\.\d{3})*,\d{2}-?$');
    for (final row in layout.rows) {
      for (var i = 0; i < row.cells.length - 1; i++) {
        final cell = TrStatementText.fold(row.cells[i].text);
        if (!wanted.any((w) => cell.endsWith(' $w') && RegExp(r'^[\d.,]+ ').hasMatch(cell))) continue;
        final next = row.cells[i + 1].text.trim();
        if (amountRe.hasMatch(next)) return TrStatementText.amountCents(next.replaceAll('-', ''));
      }
    }
    return null;
  }

  @override
  ParserOutput parse(StatementLayout layout) {
    int? amount(List<String> labels) => _looseAmount(layout, labels);

    final net = amount(['Toplam Net Ödenen', 'Net Ödenen', 'Net Ücret', 'Net Ödenen+AGİ Toplamı', 'Ele Geçen']);
    if (net == null || net <= 0) return ParserOutput.empty;

    final gross = amount(['Toplam Brüt', 'Brüt Ücret', 'Toplam Kazanç']);
    final incomeTax = amount(['Gelir Ver.Kesinti', 'Gelir Vergisi', 'Gelir Vergisi Kesintisi']);
    var stampTax = amount(['Damga Ver.Kesinti', 'Damga Vergisi']);
    // Toplu sözleşme (TİS) fark ödemesinden kesilen primler "Yasal Kesinti" toplamının dışında basılır
    final tisSgk = amount(['TİS SSK İşçi']);
    final tisUnemployment = amount(['TİS İşsizlik İşçi']);
    final baseSgk = amount(['SSK Kesintisi', 'SGK İşçi Payı', 'SGK Kesintisi']);
    final baseUnemployment = amount(['İşsizlik Primi', 'İşsizlik Sig. İşçi Payı']);
    final sgk = baseSgk == null ? null : baseSgk + (tisSgk ?? 0);
    final unemployment = baseUnemployment == null ? null : baseUnemployment + (tisUnemployment ?? 0);
    final legalTotal = amount(['Yasal Kesinti', 'Yasal Kesintiler Toplamı', 'Toplam Yasal Kesinti']);
    final otherTotal = amount(['Özel Kesinti', 'Özel Kesintiler Toplamı', 'Diğer Kesintiler'])?.abs();
    // Birim ücret (saatlik/aylık, bordronun başlığında "Ücreti 21,20" gibi). Zam tespitinin sinyali:
    // brüt fazla mesai/ikramiyeyle oynar, birim ücret yalnız zamla değişir. Etiketler tam eşleşir;
    // "Net Ücret" / "Brüt Ücret" ayrı etiketlerdir ve buraya karışmaz. Okunamazsa null (tahmin yok).
    final wage = amount(['Ücreti', 'Birim Ücret', 'Saat Ücreti', 'Saatlik Ücret', 'Aylık Ücret']);
    final baseWage = (wage == null || wage <= 0) ? null : wage;

    // Bazı bordrolarda damga vergisi kesintisi etiketsiz/yanlış etiketli basılır. Yasal kesinti toplamı
    // biliniyorsa damga = yasal toplam − (SGK + işsizlik + gelir vergisi). Makul değilse (brütün %1'inden
    // büyük) kullanılmaz; yanlış bir vergi göstermektense eksik göstermek tercih edilir.
    if (stampTax == null && legalTotal != null && baseSgk != null && incomeTax != null) {
      final derived = legalTotal - baseSgk - (baseUnemployment ?? 0) - incomeTax;
      final cap = (gross ?? net) ~/ 100;
      if (derived > 0 && derived <= cap) stampTax = derived;
    }

    final period = _period(layout) ?? DateTime.now();
    // Maaş dönem sonunda yatar; gün bilgisi yoksa ayın son günü kabul edilir
    final payDate = DateTime(period.year, period.month + 1, 0);

    final taxes = <ParsedTaxData>[
      if (incomeTax != null) ParsedTaxData(taxType: 'INCOME_TAX', amountCents: incomeTax),
      if (stampTax != null) ParsedTaxData(taxType: 'STAMP_TAX', amountCents: stampTax),
      if (sgk != null) ParsedTaxData(taxType: 'SGK_WORKER', amountCents: sgk),
      if (unemployment != null) ParsedTaxData(taxType: 'UNEMPLOYMENT', amountCents: unemployment),
    ];

    final employer = TrStatementText.labelValue(layout, ['İşyeri Unvanı', 'İşveren', 'Firma Adı', 'Şirket']);

    return ParserOutput(
      records: [
        ParsedRecord(
          cardOrAccountMask: 'BORDRO',
          date: payDate,
          type: ParsedTransactionType.credit,
          rawDescription: 'Net maaş ödemesi',
          cleanMerchant: employer ?? 'Maaş',
          counterparty: employer ?? 'İşveren',
          categoryId: 'cat_salary',
          kind: TransactionKind.salary,
          billingAmountCents: net,
          originalAmountCents: gross,
          taxes: taxes,
        ),
      ],
      accountIdentifier: 'Bordro',
      summary: StatementSummary(
        statementDate: payDate,
        payslipGrossCents: gross,
        // TİS primleri de yasal kesintidir; toplamı kalemlerle aynı kapsama getir
        payslipLegalDeductionsCents:
            legalTotal == null ? null : legalTotal + (tisSgk ?? 0) + (tisUnemployment ?? 0),
        payslipOtherDeductionsCents: otherTotal,
        payslipBaseWageCents: baseWage,
      ),
    );
  }

  DateTime? _period(StatementLayout layout) {
    for (final row in layout.rows.take(8)) {
      final m = _monthYear.firstMatch(row.text.trim());
      if (m != null) return TrStatementText.parseDate('1 ${m.group(1)} ${m.group(2)}');
    }
    final raw = TrStatementText.labelValue(layout, ['Dönem', 'Bordro Dönemi', 'Ücret Dönemi']);
    return raw == null ? null : TrStatementText.parseDate(raw.contains(' ') ? '1 $raw' : raw);
  }
}
