// test/statement_pipeline_test.dart
//
// Kişisel PDF gerektirmeyen, CI'da çalışan ekstre boru hattı birim testleri.
// Gerçek ekstrelerle uçtan uca test için bkz. test/pdf_corpus_probe_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/parser/layout/statement_layout.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';
import 'package:moneytrace/core/parser/parsers/yapikredi_card_parser.dart';
import 'package:moneytrace/core/parser/services/merchant_sanitizer.dart';
import 'package:moneytrace/core/parser/services/statement_reconciler.dart';
import 'package:moneytrace/core/parser/util/tr_statement_text.dart';

/// Tek satırlık sentetik düzen: her hücre (x, metin); y yukarıdan aşağı azalır.
List<RawTextFragment> _row(double y, List<(double, String)> cells) => [
      for (final (x, text) in cells)
        RawTextFragment(page: 1, left: x, right: x + text.length * 4.5, top: y + 4, bottom: y - 4, text: text),
    ];

void main() {
  group('TrStatementText', () {
    test('Türkçe tarih biçimleri', () {
      expect(TrStatementText.parseDate('31 Ocak 2026'), DateTime(2026, 1, 31));
      expect(TrStatementText.parseDate('06/02/26'), DateTime(2026, 2, 6));
      expect(TrStatementText.parseDate('28.02.2026'), DateTime(2026, 2, 28));
      expect(TrStatementText.parseDate('31 Şubat 2026'), isNull);
    });

    test('Tutar hücreleri işaretiyle', () {
      expect(TrStatementText.amountCents('1.234,56'), 123456);
      expect(TrStatementText.amountCents('+8.091,04'), 809104);
      expect(TrStatementText.amountCents('- 30.000,00 TL'), -3000000);
      expect(TrStatementText.amountCents('2.138,52 / 2'), isNull);
    });
  });

  group('StatementLayout', () {
    test('Aynı yükseklikteki kelimeler satır, büyük boşluklar hücre olur', () {
      final layout = StatementLayout.fromFragments([
        ..._row(500, [(40, '31'), (51, 'Ocak'), (71, '2026'), (105, 'MIGROS'), (400, '250,00')]),
        ..._row(480, [(40, 'TOPLAM'), (400, '250,00')]),
      ], pageCount: 1);
      expect(layout.rows.length, 2);
      expect(layout.rows.first.cells.map((c) => c.text), ['31 Ocak 2026', 'MIGROS', '250,00']);
    });
  });

  group('YapiKrediCardParser', () {
    test('Taksit, döviz ve ödeme satırları sütunlardan okunur', () {
      final layout = StatementLayout.fromFragments([
        ..._row(800, [(28, 'Dönem İçi Harcamalar'), (198, ': 1.469,26 TL')]),
        ..._row(790, [(28, 'Dönem İçi Ödemeler'), (198, ': +500,00 TL')]),
        ..._row(700, [(34, 'Kart Numarası'), (176, ': 5555 55** **** 1234'), (454, 'AD SOYAD')]),
        ..._row(690, [(40, 'İşlem Tarihi'), (104, 'İşlemler'), (387, 'Tutar(TL)'), (442, 'Kalan Tutar/Taksit'), (545, 'Puan')]),
        ..._row(680, [(40, '06 Mart 2026'), (105, 'ÖDEME-İNTERNET BANKACILIĞI'), (395, '+500,00')]),
        ..._row(670, [(40, '09 Mart 2026'), (105, 'HDI SIGORTA A.S.'), (300, 'ISTANBUL'), (360, 'TR'), (400, '1.069,26'), (445, '2.138,52 / 2'), (550, '642')]),
        ..._row(662, [(105, "3.207,78 TL'lik işlemin 1 / 3 taksidi")]),
        ..._row(650, [(40, '12 Mart 2026'), (105, 'DISNEY PLUS'), (300, 'LONDON'), (360, 'GBGB'), (400, '400,00')]),
        ..._row(642, [(105, 'İşlem Tutarı: 9,00 USD')]),
      ], pageCount: 1);

      final out = YapiKrediCardParser().parse(layout);
      expect(out.records.length, 3);

      final payment = out.records[0];
      expect(payment.type, ParsedTransactionType.credit);
      expect(payment.billingAmountCents, 50000);

      final insurance = out.records[1];
      expect(insurance.billingAmountCents, 106926);
      expect(insurance.installment!.currentInstallment, 1);
      expect(insurance.installment!.totalInstallment, 3);
      expect(insurance.installment!.remainingAmountCents, 213852);

      final disney = out.records[2];
      expect(disney.originalCurrency, 'USD');
      expect(disney.originalAmountCents, 900);

      expect(out.summary.periodDebitsCents, 146926);
      expect(out.summary.periodCreditsCents, 50000);
    });
  });

  group('MerchantSanitizer', () {
    test('Kelime sınırı: kısa kalıplar yanlış eşleşmez', () {
      expect(MerchantSanitizer.resolveCategory('GÜZELTEPE PETROL ÜRÜNLE'), 'cat_fuel');
      expect(MerchantSanitizer.resolveCategory('ATAKAN PETSHOP'), 'cat_pet');
      expect(MerchantSanitizer.resolveCategory('BİM R324 ÇAĞDAŞKENT'), 'cat_market');
      expect(MerchantSanitizer.resolveCategory('KOÇTAŞ YAPI MARKET'), 'cat_home');
      expect(MerchantSanitizer.resolveCategory('526. SOKAK KIRTASIYE'), 'cat_education');
    });

    test('Ödeme kuruluşu önekleri temizlenir', () {
      expect(MerchantSanitizer.sanitize('IYZICO  *LETGO.COM'), 'LETGO.COM');
      expect(MerchantSanitizer.sanitize('PAYTR/IKAS.COM'), 'IKAS.COM');
      expect(MerchantSanitizer.sanitize('ÖDEAL//OZMAYDONOZ GI'), 'OZMAYDONOZ GI');
    });
  });

  group('StatementReconciler', () {
    ParsedRecord rec(int cents, {bool credit = false, TransactionKind kind = TransactionKind.purchase, int? balance}) =>
        ParsedRecord(
          cardOrAccountMask: 'x',
          date: DateTime(2026, 1, 1),
          type: credit ? ParsedTransactionType.credit : ParsedTransactionType.debit,
          rawDescription: 'x',
          billingAmountCents: cents,
          kind: kind,
          balanceAfterCents: balance,
        );

    test('Kart: iadeyi harcamadan düşen banka gösterimi de kabul edilir', () {
      final report = StatementReconciler.check(
        records: [rec(10000), rec(2000, credit: true, kind: TransactionKind.refund), rec(5000, credit: true, kind: TransactionKind.cardPayment)],
        summary: const StatementSummary(periodDebitsCents: 8000, periodCreditsCents: 5000),
        isCardStatement: true,
      );
      expect(report.isBalanced, isTrue);
    });

    test('Vadesiz: bakiye zinciri kopunca hangi satır olduğu raporlanır', () {
      final report = StatementReconciler.check(
        records: [rec(1000, credit: true, balance: 1000), rec(300, balance: 600)],
        summary: const StatementSummary(previousBalanceCents: 0),
        isCardStatement: false,
      );
      expect(report.isBalanced, isFalse);
      expect(report.issues.single, contains('2. satır'));
    });
  });
}
