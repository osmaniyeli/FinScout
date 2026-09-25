// test/payslip_duplicate_rule_test.dart
//
// Bordro mükerrer kuralı (kullanıcı kararı 2026-09-25): dosya birebir aynıysa (SHA-256) uyarı; aynı değilse
// eklenir. Aynı ay için eşin bordrosu (aynı tutarda bile) yan yana kaydedilebilir. Kart/hesap ekstrelerinde
// aynı-dönem kontrolü ve işlem bazlı mükerrer koruması aynen kalır.
// Tüm tutarlar UYDURMA örnek sayılardır.

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/database/repositories/transaction_repository.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';
import 'package:moneytrace/features/analysis/services/payslip_analytics_service.dart';

ParsedRecord _salaryRecord(int netCents, {String employer = 'İşveren'}) => ParsedRecord(
      cardOrAccountMask: 'BORDRO',
      date: DateTime(2025, 6, 30),
      type: ParsedTransactionType.credit,
      rawDescription: 'Net maaş ödemesi',
      counterparty: employer,
      categoryId: 'cat_salary',
      kind: TransactionKind.salary,
      billingAmountCents: netCents,
    );

StatementDocumentResult _payslip(ParsedRecord record) => StatementDocumentResult(
      institution: 'Maaş Bordrosu',
      documentType: 'PAYSLIP',
      accountIdentifier: 'Bordro',
      records: [record],
      totalDebitCents: 0,
      totalCreditCents: record.billingAmountCents,
      totalTaxCents: 0,
      periodStart: record.date,
      periodEnd: record.date,
      summary: StatementSummary(statementDate: record.date),
    );

StatementDocumentResult _card(ParsedRecord record) => StatementDocumentResult(
      institution: 'Yapı Kredi',
      documentType: 'CREDIT_CARD',
      accountIdentifier: '4000 11** **** 2222',
      records: [record],
      totalDebitCents: record.billingAmountCents,
      totalCreditCents: 0,
      totalTaxCents: 0,
      periodStart: record.date,
      periodEnd: record.date,
    );

void main() {
  group('aynı-dönem kontrolü', () {
    test('bordroda uygulanmaz (eşin / fark bordrosu eklenebilir)', () {
      expect(TransactionRepository.samePeriodCheckApplies(_payslip(_salaryRecord(3000000))), isFalse);
    });

    test('kart ve hesap ekstresinde aynen uygulanır', () {
      final purchase = ParsedRecord(
        cardOrAccountMask: '2222',
        date: DateTime(2025, 6, 12),
        type: ParsedTransactionType.debit,
        rawDescription: 'MARKET ALISVERIS',
        billingAmountCents: 45050,
      );
      expect(TransactionRepository.samePeriodCheckApplies(_card(purchase)), isTrue);
      final checking = StatementDocumentResult(
        institution: 'Enpara',
        documentType: 'CHECKING',
        accountIdentifier: 'TR00 **** 1234',
        records: [purchase],
        totalDebitCents: 45050,
        totalCreditCents: 0,
        totalTaxCents: 0,
        periodStart: purchase.date,
        periodEnd: purchase.date,
      );
      expect(TransactionRepository.samePeriodCheckApplies(checking), isTrue);
    });
  });

  group('işlem mükerrer anahtarı', () {
    String key(StatementDocumentResult r, String sha) => TransactionRepository.transactionDedupKey(
          result: r,
          accountId: TransactionRepository.accountIdFor(r),
          fileSha256: sha,
          record: r.records.single,
        );

    test('aynı ay, aynı tutarlı iki farklı bordro dosyası ayrı kayıt olur', () {
      final mine = _payslip(_salaryRecord(3000000));
      final spouse = _payslip(_salaryRecord(3000000));
      expect(TransactionRepository.accountIdFor(mine), TransactionRepository.accountIdFor(spouse));
      expect(key(mine, 'sha-aaa'), isNot(key(spouse, 'sha-bbb')));
    });

    test('aynı ay, farklı tutarlı iki bordro ayrı kayıt olur', () {
      expect(key(_payslip(_salaryRecord(3000000)), 'sha-aaa'),
          isNot(key(_payslip(_salaryRecord(2750000)), 'sha-bbb')));
    });

    test('kart ekstresinde dosya özeti anahtara girmez: yeniden indirilen ekstrenin işlemi atlanır', () {
      final purchase = ParsedRecord(
        cardOrAccountMask: '2222',
        date: DateTime(2025, 6, 12),
        type: ParsedTransactionType.debit,
        rawDescription: 'MARKET  alisveris',
        billingAmountCents: 45050,
      );
      final r = _card(purchase);
      expect(key(r, 'sha-first-download'), key(r, 'sha-second-download'));
    });
  });

  test('bordrolar tek "Bordro" hesabına düşer (işveren hesap kimliğine girmez)', () {
    final a = _payslip(_salaryRecord(3000000, employer: 'Örnek Sanayi A.Ş.'));
    final b = _payslip(_salaryRecord(2500000, employer: 'Deneme Ticaret Ltd.'));
    expect(TransactionRepository.accountIdFor(a), TransactionRepository.accountIdFor(b));
  });

  test('aynı aydaki iki bordro hane geliri olarak toplanır; birim ücret yüksek olandır', () {
    Map<String, Object?> row(int net, int gross, int wage) => {
          'transaction_date': '2025-06-30',
          'billing_amount_cents': net,
          'original_amount_cents': gross,
          'base_wage_cents': wage,
        };
    final months = PayslipAnalyticsService.buildMonths(
      [row(3000000, 4000000, 5500), row(2500000, 3300000, 4800)],
      [
        {'transaction_date': '2025-06-30', 'tax_type': 'INCOME_TAX', 'amount_cents': 400000},
        {'transaction_date': '2025-06-30', 'tax_type': 'INCOME_TAX', 'amount_cents': 300000},
      ],
    );
    final june = months.single;
    expect(june.netCents, 5500000);
    expect(june.grossCents, 7300000);
    expect(june.incomeTaxCents, 700000);
    expect(june.baseWageCents, 5500);
  });
}
