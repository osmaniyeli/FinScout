// lib/features/fees/presentation/fee_report_text.dart

import '../../../core/utils/currency_normalizer.dart';
import '../../tax_analytics/services/tax_analysis_service.dart';
import '../services/fee_report_service.dart';
import 'fee_period.dart';

/// Ekranda ve paylaşılan raporda ortak kullanılan metinler.
class FeeTexts {
  FeeTexts._();

  static String get computedNote =>
      'Ekstrede faiz, BSMV ve KKDF tek satır; vergi payı '
      '%${FeeReportService.bsmvOnInterestPct} + %${FeeReportService.kkdfOnInterestPct} oranla ayrıldı.';

  static const vatNote =
      'Fişteki KDV değil; harcama kategorisine göre yürürlükteki oranla hesaplanan tahmindir. '
      '"~" karma oranlı kategoriler (ör. market: gıda %1–10, temizlik %20). '
      'Akaryakıt ÖTV\'si ve iletişimdeki ÖİV dahil değildir.';

  /// Tahmine girmeyen harcamalar; tutar yoksa null.
  static String? vatExclusionNote(TaxAnalysis vat) {
    final parts = <String>[
      if (vat.excludedForeignCents > 0)
        'döviz cinsinden harcamalar (${CurrencyNormalizer.formatCents(vat.excludedForeignCents)})',
      if (vat.excludedUnclassifiedCents > 0)
        'sınıflanamayan harcamalar (${CurrencyNormalizer.formatCents(vat.excludedUnclassifiedCents)})',
    ];
    if (parts.isEmpty) return null;
    return 'Tahmine katılmadı: ${parts.join(', ')}.';
  }
}

/// Kalem toplamları, bir grup içinde tutara göre büyükten küçüğe.
List<MapEntry<FeeItem, int>> feeItemsOf(FeeReport report, FeeGroup group) =>
    report.byItem.entries.where((e) => e.key.group == group).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

/// Kalemde oranla hesaplanan satır var mı?
bool feeItemIsComputed(FeeReport report, FeeItem item) =>
    report.lines.any((l) => l.item == item && l.computed);

/// Paylaşılan rapora masraf bölümünü ve (ayrı, "tahmini" etiketli) KDV bölümünü yazar.
void writeFeeReportSection(
  StringBuffer b, {
  required FeePeriod period,
  required FeeReport report,
  TaxAnalysis? vat,
}) {
  String fmt(int c) => CurrencyNormalizer.formatCents(c);

  b.writeln('MASRAFLAR (${period.label}):');
  if (report.isEmpty) {
    b.writeln('Bu dönemde masraf satırı yok.');
  } else {
    for (final g in FeeGroup.values) {
      b.writeln('${g.label}: ${fmt(report.totalOf(g))}');
      for (final e in feeItemsOf(report, g)) {
        final tag = feeItemIsComputed(report, e.key) ? ' (hesaplanan)' : '';
        b.writeln('- ${e.key.label}: ${fmt(e.value)}$tag');
      }
    }
    if (report.hasComputed) b.writeln('Not: ${FeeTexts.computedNote}');
  }
  b.writeln('');

  if (vat != null) {
    b.writeln('TAHMİNİ KDV (${period.label}) — tahmindir, ödenen vergi toplamına dahil değildir:');
    if (vat.isEmpty) {
      b.writeln('Tahmin yapılacak sınıflanmış TL harcama yok.');
    } else {
      b.writeln('Tahmini KDV: ~${fmt(vat.vatTotal)} (${fmt(vat.spentTotal)} harcama içinde)');
      for (final v in vat.vat) {
        final pct = '${v.approximate ? '~' : ''}%${(v.rate * 100).round()}';
        b.writeln('- ${v.categoryName} ($pct): ~${fmt(v.vatCents)}');
      }
    }
    final excl = FeeTexts.vatExclusionNote(vat);
    if (excl != null) b.writeln(excl);
    b.writeln('');
  }
}
