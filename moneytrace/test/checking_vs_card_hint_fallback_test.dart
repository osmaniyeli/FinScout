// test/checking_vs_card_hint_fallback_test.dart
//
// KRİTİK GÜVENLİK REGRESYONU: Kurum/tür fingerprint'le tespit edilemeyen bir belge (ör. Yapı Kredi
// VADESİZ hesap ekstresi — bank_detector.dart'ta yalnız YK KREDİ KARTI parmak izi var, vadesiz için
// yok) yüklendiğinde, yükleme ekranındaki VARSAYILAN ipucu ('CREDIT_CARD', bkz. statement_upload_sheet
// _selectedDocType) belgeyi kart ekstresi gibi (isCardStatement=true) okutuyordu. Bu modda
// GenericBankStatementParser, "+" ile BAŞLAMAYAN her satırı (gelen para dahil) gider sayar — yani bir
// vadesiz hesaba yatan maaş bile sessizce gider yazılır. StatementOrchestrator artık bu durumu içerik
// bazlı ikinci bir kontrolle (kart alanı yok + BAKİYE sütunu var) düzeltip docType'ı CHECKING'e indiriyor.

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/parser/layout/statement_layout.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';
import 'package:moneytrace/core/parser/services/bank_detector.dart';
import 'package:moneytrace/core/parser/services/statement_orchestrator.dart';

/// Tek satırlık sentetik düzen: her hücre (x, metin); y yukarıdan aşağı azalır.
/// (bkz. test/statement_pipeline_test.dart _row yardımcısı)
List<RawTextFragment> _row(double y, List<(double, String)> cells) => [
      for (final (x, text) in cells)
        RawTextFragment(page: 1, left: x, right: x + text.length * 4.5, top: y + 4, bottom: y - 4, text: text),
    ];

/// Kurum adı GEÇMEYEN, yalnız TARİH/AÇIKLAMA/TUTAR/BAKİYE sütunlu bir vadesiz hesap hareketi tablosu.
/// Bilerek hiçbir banka markası ya da kart alanı (ASGARİ TUTAR/DÖNEM BORCU/KART NUMARASI/WORLDPUAN)
/// içermez: bank_detector bunu genericUnknown/unknown olarak tespit etmeli (gerçek YK vadesiz ekstresi
/// bu şekilde düşüyor, bkz. görev bulgusu).
StatementLayout _syntheticCheckingLayoutWithoutBrand() {
  final fragments = [
    ..._row(500, [(0, 'TARIH'), (100, 'ACIKLAMA'), (300, 'TUTAR'), (400, 'BAKIYE')]),
    // Gelen para: banka bunu tutar sütununda "+" işaretiyle yazar, açıklamada değil.
    ..._row(480, [(0, '10.01.2026'), (100, 'MAAS ODEMESI'), (300, '+5.000,00'), (400, '10.000,00')]),
  ];
  return StatementLayout.fromFragments(fragments, pageCount: 1);
}

void main() {
  group('StatementOrchestrator: docType hint fallback güvenlik düzeltmesi', () {
    test('BankDetector: fingerprint yoksa institution=genericUnknown, documentType=unknown', () {
      final layout = _syntheticCheckingLayoutWithoutBrand();
      final detection = BankDetector.identify(layout.plainText);
      expect(detection.institution, SupportedInstitution.genericUnknown);
      expect(detection.documentType, DocumentType.unknown);
    });

    test('BankDetector: kart alanı yok + BAKİYE sütunu var → hesap hareketi içeriği kabul edilir', () {
      final layout = _syntheticCheckingLayoutWithoutBrand();
      expect(BankDetector.hasCardStatementFingerprint(layout.plainText), isFalse);
      expect(BankDetector.hasAccountBalanceColumn(layout.plainText), isTrue);
    });

    test(
        'Kurum tespit edilemeyip ipucu CREDIT_CARD olsa da (yükleme ekranı varsayılanı): '
        'BAKİYE sütunlu, kart alanı olmayan belge CHECKING olarak okunur; gelen para gider sayılmaz',
        () async {
      final layout = _syntheticCheckingLayoutWithoutBrand();
      final result = await StatementOrchestrator().processDocument(
        layout: layout,
        documentTypeHint: 'CREDIT_CARD', // statement_upload_sheet._selectedDocType varsayılanı
      );

      expect(result.documentType, 'CHECKING', reason: 'isCardStatement=true kalsaydı gelir dahi gider yazılırdı');
      expect(result.records, hasLength(1));
      expect(result.records.single.type, ParsedTransactionType.credit,
          reason: '+5.000,00 tutarlı gelen para; kart mantığıyla ("+ ile başlamayan HER satır gider") '
              'okunsaydı DEBIT olurdu');
      expect(result.records.single.billingAmountCents, 500000);
    });

    test('Kart alanları (ör. ASGARİ TUTAR) varsa CREDIT_CARD ipucu korunur (gerçek kart ekstresi bozulmaz)',
        () async {
      final fragments = [
        ..._row(500, [(0, 'TARIH'), (100, 'ACIKLAMA'), (300, 'TUTAR')]),
        ..._row(480, [(0, '10.01.2026'), (100, 'MARKET ALISVERISI'), (300, '150,00')]),
        ..._row(460, [(0, 'ASGARİ TUTAR'), (100, '500,00')]),
      ];
      final layout = StatementLayout.fromFragments(fragments, pageCount: 1);

      final result = await StatementOrchestrator().processDocument(
        layout: layout,
        documentTypeHint: 'CREDIT_CARD',
      );

      expect(result.documentType, 'CREDIT_CARD');
    });
  });
}
