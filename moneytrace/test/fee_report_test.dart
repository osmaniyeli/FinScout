// test/fee_report_test.dart
//
// Masraf raporu: kalem sınıflandırma, "BSMV dahil" faiz ayrıştırması ve grup toplamları.

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/features/fees/presentation/fee_period.dart';
import 'package:moneytrace/features/fees/presentation/fee_report_text.dart';
import 'package:moneytrace/features/fees/services/fee_report_service.dart';
import 'package:moneytrace/features/tax_analytics/services/tax_analysis_service.dart';

Map<String, Object?> _tx(String desc, int cents,
        {String kind = 'INTERESTFEE', String type = 'DEBIT', String account = 'CREDIT_CARD', int separateTax = 0}) =>
    {
      'transaction_date': '2026-08-15',
      'raw_description': desc,
      'transaction_type': type,
      'tx_kind': kind,
      'billing_amount_cents': cents,
      'statement_id': 's1',
      'account_type': account,
      'separate_tax_lines': separateTax,
    };

void main() {
  group('FeeReportService.classify', () {
    test('Kalemler açıklamadan ayrışır', () {
      expect(FeeReportService.classify('KART AİDATI', 'INTERESTFEE'), FeeItem.cardAnnualFee);
      expect(FeeReportService.classify('GECİKME FAİZİ', 'INTERESTFEE'), FeeItem.lateInterest);
      expect(FeeReportService.classify('DÖNEM FAİZİ', 'INTERESTFEE'), FeeItem.purchaseInterest);
      expect(FeeReportService.classify('FAST ÜCRETİ', 'INTERESTFEE'), FeeItem.transferFee);
      expect(FeeReportService.classify('HESAP İŞLETİM ÜCRETİ', 'INTERESTFEE'), FeeItem.accountFee);
      expect(FeeReportService.classify('KMH FAİZİ', 'INTERESTFEE'), FeeItem.overdraftInterest);
      expect(FeeReportService.classify('BSMV', 'TAX'), FeeItem.bsmv);
      expect(FeeReportService.classify('VADELİ STOPAJ', 'TAX'), FeeItem.withholding);
      expect(FeeReportService.classify('MOTORLU TAŞITLAR VERGİSİ', 'TAX'), FeeItem.mtv);
      expect(FeeReportService.classify('GELİR İDARESİ BAŞKANLIĞI', 'TAX'), FeeItem.otherTaxPayment);
    });
  });

  group('FeeReportService.buildLines', () {
    test('Kartta "BSMV dahil" faiz: faiz + BSMV + KKDF toplamı ekstredeki tutara eşit', () {
      final lines = FeeReportService.buildLines([_tx('DÖNEM FAİZİ', 13001)], const []);
      expect(lines.length, 3);
      expect(lines.every((l) => l.computed), isTrue);
      expect(lines.fold<int>(0, (s, l) => s + l.amountCents), 13001);
      final report = FeeReport(from: DateTime(2026, 8), to: DateTime(2026, 9), lines: lines);
      expect(report.byItem[FeeItem.purchaseInterest], 10001);
      expect(report.byItem[FeeItem.bsmv], 1500);
      expect(report.byItem[FeeItem.kkdf], 1500);
    });

    test('Ekstrede ayrı BSMV/KKDF satırı varsa faiz bölünmez (çift sayım yok)', () {
      final lines = FeeReportService.buildLines([
        _tx('DÖNEM FAİZİ', 10000, separateTax: 2),
        _tx('BSMV', 1500, kind: 'TAX', separateTax: 2),
        _tx('KKDF', 1500, kind: 'TAX', separateTax: 2),
      ], const []);
      expect(lines.length, 3);
      expect(lines.any((l) => l.computed), isFalse);
    });

    test('Vadesizde faiz bölünmez; iade eksi yazılır', () {
      final lines = FeeReportService.buildLines([
        _tx('KMH FAİZİ', 5000, account: 'CHECKING'),
        _tx('KART AİDATI', 60000),
        _tx('KART AİDATI İADESİ', 60000, type: 'CREDIT'),
      ], const []);
      final report = FeeReport(from: DateTime(2026, 8), to: DateTime(2026, 9), lines: lines);
      expect(report.byItem[FeeItem.overdraftInterest], 5000);
      expect(report.byItem.containsKey(FeeItem.cardAnnualFee), isFalse); // aidat iade edildi: net 0
      expect(report.totalOf(FeeGroup.bankCost), 5000);
    });

    test('Bordro kesintileri vergi ve prim gruplarına ayrı gider', () {
      final lines = FeeReportService.buildLines(const [], [
        {'transaction_date': '2026-06-30', 'tax_type': 'INCOME_TAX', 'amount_cents': 1813444},
        {'transaction_date': '2026-06-30', 'tax_type': 'STAMP_TAX', 'amount_cents': 55818},
        {'transaction_date': '2026-06-30', 'tax_type': 'SGK_WORKER', 'amount_cents': 1443660},
        {'transaction_date': '2026-06-30', 'tax_type': 'UNEMPLOYMENT', 'amount_cents': 103119},
      ]);
      final report = FeeReport(from: DateTime(2026, 6), to: DateTime(2026, 7), lines: lines);
      expect(report.totalOf(FeeGroup.taxPaid), 1813444 + 55818);
      expect(report.totalOf(FeeGroup.premium), 1443660 + 103119);
      expect(report.totalOf(FeeGroup.bankCost), 0);
    });
  });

  group('Masraflar dönemi ve paylaşım metni', () {
    test('Ay dönemi yıl sınırında geri/ileri gider, geleceğe geçmez', () {
      const jan = FeePeriod(year: 2026, month: 1);
      expect(jan.previous, const FeePeriod(year: 2025, month: 12));
      expect(const FeePeriod(year: 2025, month: 12).next, jan);
      expect(jan.to, DateTime(2026, 2, 1));
      final now = DateTime(2026, 9, 24);
      expect(FeePeriod.thisMonth(now).canGoNext(now), isFalse);
      expect(const FeePeriod(year: 2026, month: 8).canGoNext(now), isTrue);
      expect(FeePeriod.thisYear(now).from, DateTime(2026, 1, 1));
      expect(FeePeriod.thisYear(now).to, DateTime(2027, 1, 1));
    });

    test('Rapor metni üç grubu ayrı yazar; KDV tahmini ayrı ve etiketli', () {
      final lines = FeeReportService.buildLines([_tx('DÖNEM FAİZİ', 13000)], [
        {'transaction_date': '2026-08-31', 'tax_type': 'INCOME_TAX', 'amount_cents': 1000},
        {'transaction_date': '2026-08-31', 'tax_type': 'SGK_WORKER', 'amount_cents': 2000},
      ]);
      final report = FeeReport(from: DateTime(2026, 8), to: DateTime(2026, 9), lines: lines);
      final vat = TaxAnalysis(
        from: DateTime(2026, 8),
        to: DateTime(2026, 9),
        vat: const [VatEstimate('Restoran', 11000, 0.10, false)],
        excludedForeignCents: 5000,
        excludedUnclassifiedCents: 7000,
      );
      final b = StringBuffer();
      writeFeeReportSection(b,
          period: const FeePeriod(year: 2026, month: 8), report: report, vat: vat);
      final text = b.toString();
      expect(text, contains('MASRAFLAR (Ağustos 2026)'));
      expect(text, contains('Banka maliyeti:'));
      expect(text, contains('Ödenen vergi:'));
      expect(text, contains('Prim:'));
      expect(text, contains('(hesaplanan)'));
      expect(text, contains('%15 + %15'));
      expect(text, contains('TAHMİNİ KDV'));
      expect(text, contains('döviz cinsinden'));
      expect(text, contains('sınıflanamayan'));
      // SGK prim grubunda; ödenen vergi toplamına girmez
      expect(report.totalOf(FeeGroup.taxPaid), 1000);
      expect(vat.vatTotal, 1000);
    });

    test('KDV oran tablosu sınıflanamayan kategoriye oran varsaymaz', () {
      expect(TaxAnalysisService.vatRates.containsKey('cat_general'), isFalse);
    });
  });
}
