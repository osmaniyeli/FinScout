// lib/features/fees/presentation/fees_view.dart

import 'package:flutter/material.dart';

import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../tax_analytics/services/tax_analysis_service.dart';
import '../services/fee_report_service.dart';
import 'fee_period.dart';
import 'fee_report_text.dart';

/// Analiz > Masraflar içeriği: dönem seçimi, üç ayrı alt toplam, kalem dökümü ve ayrı "Tahmini KDV".
/// Durum (dönem, yükleme) AnalysisScreen'de tutulur; paylaşılan rapor aynı veriyi kullanır.
class FeesView extends StatelessWidget {
  const FeesView({
    super.key,
    required this.period,
    required this.report,
    required this.vat,
    required this.isLoading,
    required this.onPeriodChanged,
    required this.onUploadStatement,
    required this.onShare,
  });

  final FeePeriod period;
  final FeeReport? report;
  final TaxAnalysis? vat;
  final bool isLoading;
  final ValueChanged<FeePeriod> onPeriodChanged;
  final VoidCallback onUploadStatement;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final r = report;
    // Tablette okunabilir sütun (en fazla 720 dp), ortalı
    return AdaptiveListPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 84),
      builder: (context, padding) => ListView(
      padding: padding,
      children: [
        _PeriodSelector(period: period, onChanged: onPeriodChanged),
        const SizedBox(height: 14),
        if (isLoading && r == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (r == null || r.isEmpty)
          _EmptyFees(onUpload: onUploadStatement)
        else ...[
          _GroupTotals(report: r),
          const SizedBox(height: 20),
          for (final g in FeeGroup.values)
            if (feeItemsOf(r, g).isNotEmpty) ...[
              _GroupSection(report: r, group: g),
              const SizedBox(height: 18),
            ],
          if (r.hasComputed)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                FeeTexts.computedNote,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                    height: 1.4),
              ),
            ),
        ],
        if (vat != null) ...[
          const SizedBox(height: 4),
          _VatEstimateSection(vat: vat!),
          const SizedBox(height: 18),
        ],
        if (r != null && (!r.isEmpty || !(vat?.isEmpty ?? true)))
          OutlinedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Raporu paylaş',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final FeePeriod period;
  final ValueChanged<FeePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Bu ay')),
            ButtonSegment(value: true, label: Text('Bu yıl')),
          ],
          selected: {period.isYear},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(
              s.first ? FeePeriod.thisYear() : FeePeriod.thisMonth()),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (!period.isYear)
              IconButton(
                tooltip: 'Önceki ay',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => onChanged(period.previous),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: period.isYear ? 10 : 0),
                child: Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
            if (!period.isYear)
              IconButton(
                tooltip: 'Sonraki ay',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed:
                    period.canGoNext() ? () => onChanged(period.next) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyFees extends StatelessWidget {
  const _EmptyFees({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 32, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Bu dönemde masraf satırı yok',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kart ve hesap ekstrelerindeki faiz, ücret, BSMV/KKDF satırları ve bordrodaki '
            'vergi/prim kesintileri burada kalem kalem listelenir. Bu dönemin ekstresini veya bordronu yükle.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Ekstre yükle'),
          ),
        ],
      ),
    );
  }
}

/// Üç alt toplam; bilerek tek bir genel toplamda birleştirilmez.
class _GroupTotals extends StatelessWidget {
  const _GroupTotals({required this.report});

  final FeeReport report;

  @override
  Widget build(BuildContext context) {
    return FinanceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (final (i, g) in FeeGroup.values.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(g.label,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                  Text(CurrencyNormalizer.formatCents(report.totalOf(g)),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.report, required this.group});

  final FeeReport report;
  final FeeGroup group;

  @override
  Widget build(BuildContext context) {
    final items = feeItemsOf(report, group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(group.label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ),
        FinanceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, e) in items.indexed) ...[
                if (i > 0)
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.divider),
                InkWell(
                  onTap: () => showFeeLinesSheet(context, report, e.key),
                  child: Padding(
                    padding:
                        const EdgeInsets.only(left: 16, right: 8, top: 12, bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(e.key.label,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              if (feeItemIsComputed(report, e.key))
                                const _ComputedTag(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(CurrencyNormalizer.formatCents(e.value),
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ComputedTag extends StatelessWidget {
  const _ComputedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('hesaplanan',
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary)),
    );
  }
}

/// Kalemin satırları: tarih, açıklama, tutar.
void showFeeLinesSheet(BuildContext context, FeeReport report, FeeItem item) {
  final lines = report.lines.where((l) => l.item == item).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final total = lines.fold<int>(0, (s, l) => s + l.amountCents);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(item.label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
              '${item.group.label} · ${lines.length} satır · ${CurrencyNormalizer.formatCents(total)}',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          for (final (i, l) in lines.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(formatFeeDate(l.date),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.description,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (l.computed)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: _ComputedTag(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(CurrencyNormalizer.formatCents(l.amountCents),
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
          if (lines.any((l) => l.computed)) ...[
            const SizedBox(height: 8),
            Text(FeeTexts.computedNote,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                    height: 1.4)),
          ],
        ],
      ),
    ),
  );
}

/// Ayrı "Tahmini KDV" bölümü: gerçek toplamlarla karışmaz, açıkça tahmin olarak etiketli.
class _VatEstimateSection extends StatelessWidget {
  const _VatEstimateSection({required this.vat});

  final TaxAnalysis vat;

  @override
  Widget build(BuildContext context) {
    String pct(double r) => '%${(r * 100).round()}';
    final exclusion = FeeTexts.vatExclusionNote(vat);
    const noteStyle = TextStyle(
        fontSize: 11,
        fontStyle: FontStyle.italic,
        color: AppColors.textSecondary,
        height: 1.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Text('Tahmini KDV',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.scoutBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('tahmin',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.scoutBadgeText)),
              ),
            ],
          ),
        ),
        FinanceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (vat.isEmpty)
                const Text(
                    'Bu dönemde KDV tahmini yapılacak sınıflanmış TL harcama yok.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary))
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('~${CurrencyNormalizer.formatCents(vat.vatTotal)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          '${CurrencyNormalizer.formatCents(vat.spentTotal)} harcama içinde',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final v in vat.vat)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(v.categoryName,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        Text('${v.approximate ? '~' : ''}${pct(v.rate)}  ',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text('~${CurrencyNormalizer.formatCents(v.vatCents)}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(FeeTexts.vatNote, style: noteStyle),
              ],
              if (exclusion != null) ...[
                const SizedBox(height: 6),
                Text(exclusion, style: noteStyle),
              ],
              const SizedBox(height: 6),
              const Text(
                  'Bu tutar ödenen vergi toplamına eklenmez.',
                  style: noteStyle),
            ],
          ),
        ),
      ],
    );
  }
}
