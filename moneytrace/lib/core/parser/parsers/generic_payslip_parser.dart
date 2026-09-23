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

  @override
  ParserOutput parse(StatementLayout layout) {
    int? amount(List<String> labels) => TrStatementText.labelAmount(layout, labels);

    final net = amount(['Toplam Net Ödenen', 'Net Ödenen', 'Net Ücret', 'Net Ödenen+AGİ Toplamı', 'Ele Geçen']);
    if (net == null || net <= 0) return ParserOutput.empty;

    final gross = amount(['Toplam Brüt', 'Brüt Ücret', 'Toplam Kazanç']);
    final incomeTax = amount(['Gelir Ver.Kesinti', 'Gelir Vergisi', 'Gelir Vergisi Kesintisi']);
    final stampTax = amount(['Damga Ver.Kesinti', 'Damga Vergisi']);
    final sgk = amount(['SSK Kesintisi', 'SGK İşçi Payı', 'SGK Kesintisi']);
    final unemployment = amount(['İşsizlik Primi', 'İşsizlik Sig. İşçi Payı']);

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
      summary: StatementSummary(statementDate: payDate),
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
