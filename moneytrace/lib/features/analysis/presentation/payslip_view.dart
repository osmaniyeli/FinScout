// lib/features/analysis/presentation/payslip_view.dart

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/data_changes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';
import '../services/payslip_analytics_service.dart';

/// Analiz > Maaş & Vergi: yüklenen bordrolardan yıllar boyu maaş ve yasal kesinti geçmişi.
/// Filtreler (yıl, ölçü, aylık/yıllık) yalnız görünümü değiştirir; tüm sayılar bordrolardan gelir.
class PayslipView extends StatefulWidget {
  const PayslipView({super.key});

  @override
  State<PayslipView> createState() => _PayslipViewState();
}

enum _Granularity { monthly, yearly }

const _monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
const _monthShort = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

// Kesinti kırılımı renkleri (Kesintiler ölçüsünde yığılmış çubuk)
const _incomeTaxColor = AppColors.tax;
const _stampTaxColor = Color(0xFFA5B4FC);
const _socialColor = AppColors.installment;

Color _metricColor(PayslipMetric m) => switch (m) {
      PayslipMetric.net => AppColors.incomeGreen,
      PayslipMetric.gross => AppColors.actionPrimary,
      PayslipMetric.tax => AppColors.tax,
      PayslipMetric.deductions => AppColors.tax,
    };

String _monthLabel(int year, int month) => '${_monthNames[month - 1]} $year';

String _pctText(double ratio, {bool signed = false}) {
  final v = (ratio * 100).toStringAsFixed(1).replaceAll('.', ',');
  final sign = signed && ratio > 0 ? '+' : '';
  return '$sign%$v';
}

/// Eksen etiketi: 45.000 → "45 B", 1.250.000 → "1,3 Mn".
String _compactTl(double tl) {
  if (tl >= 1000000) return '${(tl / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Mn';
  if (tl >= 1000) return '${(tl / 1000).round()} B';
  return tl.round().toString();
}

class _PayslipViewState extends State<PayslipView> {
  final _service = PayslipAnalyticsService();
  List<PayslipMonth>? _months;
  bool _loading = true;
  String? _error;
  int _request = 0;

  Set<int> _years = {}; // boş = tümü
  PayslipMetric _metric = PayslipMetric.net;
  _Granularity _granularity = _Granularity.monthly;

  @override
  void initState() {
    super.initState();
    DataChanges.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    DataChanges.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final months = await _service.loadMonths();
      if (!mounted || request != _request) return;
      final available = PayslipAnalyticsService.yearsOf(months).toSet();
      setState(() {
        _months = months;
        _years = _years.intersection(available);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = 'Bordro verisi okunamadı: $e';
      });
    }
  }

  void _upload() => StatementUploadSheet.show(context, documentTypeHint: 'PAYSLIP', onImportSuccess: _load);

  @override
  Widget build(BuildContext context) {
    final months = _months;
    if (_loading && months == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && months == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    if (months == null || months.isEmpty) return _EmptyPayslips(onUpload: _upload);

    final allYears = PayslipAnalyticsService.yearsOf(months);
    final picked = PayslipAnalyticsService.filterYears(months, _years);

    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 84),
      children: [
        _ChipRow(children: [
          _Chip(label: 'Tümü', selected: _years.isEmpty, onTap: () => setState(() => _years = {})),
          for (final y in allYears.reversed)
            _Chip(
              label: '$y',
              selected: _years.contains(y),
              onTap: () => setState(() {
                final next = Set.of(_years);
                next.contains(y) ? next.remove(y) : next.add(y);
                _years = next.length == allYears.length ? {} : next;
              }),
            ),
        ]),
        const SizedBox(height: 8),
        _ChipRow(children: [
          for (final m in PayslipMetric.values)
            _Chip(label: m.label, selected: _metric == m, onTap: () => setState(() => _metric = m)),
        ]),
        const SizedBox(height: 8),
        _ChipRow(children: [
          _Chip(
              label: 'Aylık',
              selected: _granularity == _Granularity.monthly,
              onTap: () => setState(() => _granularity = _Granularity.monthly)),
          _Chip(
              label: 'Yıllık',
              selected: _granularity == _Granularity.yearly,
              onTap: () => setState(() => _granularity = _Granularity.yearly)),
        ]),
        const SizedBox(height: 14),
        _ChartCard(months: months, years: _years, metric: _metric, granularity: _granularity),
        const SizedBox(height: 20),
        const Text('Bu aralıkta',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        _Insights(picked: picked, allMonths: months, metric: _metric),
        const SizedBox(height: 14),
        const Text(
          'Rakamlar yalnızca yüklediğin bordrolardan hesaplanır. Bordrosu olmayan aylar tahmin edilmez, '
          'grafikte boş kalır.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _upload,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Bordro ekle', style: TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in children) Padding(padding: const EdgeInsets.only(right: 8), child: c),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
        selectedColor: AppColors.actionPrimary,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.actionPrimary : AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        visualDensity: VisualDensity.compact,
      );
}

/// Grafikteki bir çubuk: etiket, değer ve (Kesintiler için) kırılım.
class _Bar {
  const _Bar({required this.axisLabel, required this.tooltipTitle, this.month, this.value, this.stack = const []});
  final String axisLabel;
  final String tooltipTitle;
  final PayslipMonth? month;
  final int? value;
  final List<(String, int, Color)> stack;
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.months, required this.years, required this.metric, required this.granularity});
  final List<PayslipMonth> months;
  final Set<int> years;
  final PayslipMetric metric;
  final _Granularity granularity;

  static List<(String, int, Color)> _stackOf(int? incomeTax, int? stamp, int? social) => [
        if (incomeTax != null && incomeTax > 0) ('Gelir vergisi', incomeTax, _incomeTaxColor),
        if (stamp != null && stamp > 0) ('Damga vergisi', stamp, _stampTaxColor),
        if (social != null && social > 0) ('SGK + işsizlik', social, _socialColor),
      ];

  List<_Bar> _bars() {
    final stacked = metric == PayslipMetric.deductions;
    if (granularity == _Granularity.monthly) {
      final slots = PayslipAnalyticsService.monthlySlots(months, years: years);
      return [
        for (final (i, s) in slots.indexed)
          _Bar(
            axisLabel: (s.monthOfYear == 1 || i == 0)
                ? "${_monthShort[s.monthOfYear - 1]}\n'${(s.year % 100).toString().padLeft(2, '0')}"
                : _monthShort[s.monthOfYear - 1],
            tooltipTitle: _monthLabel(s.year, s.monthOfYear),
            month: s.month,
            value: s.month?.valueOf(metric),
            stack: stacked && s.month != null
                ? _stackOf(s.month!.incomeTaxCents, s.month!.stampTaxCents, s.month!.socialCents)
                : const [],
          ),
      ];
    }
    final picked = PayslipAnalyticsService.filterYears(months, years);
    return [
      for (final y in PayslipAnalyticsService.yearlyTotals(picked))
        _Bar(
          axisLabel: '${y.year}',
          tooltipTitle: y.monthsCovered == 12 ? '${y.year}' : '${y.year} (${y.monthsCovered} ay bordro)',
          value: y.valueOf(metric),
          stack: stacked
              ? _stackOf(
                  PayslipAnalyticsService.filterYears(picked, {y.year})
                      .map((m) => m.incomeTaxCents)
                      .whereType<int>()
                      .fold<int>(0, (a, b) => a + b),
                  PayslipAnalyticsService.filterYears(picked, {y.year})
                      .map((m) => m.stampTaxCents)
                      .whereType<int>()
                      .fold<int>(0, (a, b) => a + b),
                  y.socialCents,
                )
              : const [],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars();
    final color = _metricColor(metric);
    final values = bars.map((b) => b.value).whereType<int>().toList();
    final title = '${granularity == _Granularity.monthly ? 'Aylık' : 'Yıllık'} · ${metric.title}';

    return FinanceCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          if (metric == PayslipMetric.deductions) ...[
            const SizedBox(height: 8),
            const Wrap(spacing: 12, runSpacing: 4, children: [
              _Legend('Gelir vergisi', _incomeTaxColor),
              _Legend('Damga', _stampTaxColor),
              _Legend('SGK + işsizlik', _socialColor),
            ]),
          ],
          const SizedBox(height: 14),
          if (values.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Bu aralıktaki bordrolarda "${metric.label}" bilgisi okunamadı.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              const minSlot = 22.0;
              final width = math.max(constraints.maxWidth, bars.length * minSlot + 44);
              // Grafik kendi katmanında: kaydırma ve çevredeki çip/metin değişimleri onu yeniden boyamaz
              final chart = RepaintBoundary(
                child: SizedBox(width: width, height: 220, child: _chart(bars, values, color, width)),
              );
              if (width <= constraints.maxWidth) return chart;
              // Uzun geçmişte en yeni aylar görünsün: kaydırma sağdan başlar
              return SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: chart);
            }),
          if (granularity == _Granularity.monthly && bars.any((b) => b.month == null)) ...[
            const SizedBox(height: 8),
            const Text('Boş sütunlar: o ayın bordrosu yüklenmemiş.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _chart(List<_Bar> bars, List<int> values, Color color, double width) {
    final maxTl = values.reduce(math.max) / 100;
    final top = maxTl <= 0 ? 1.0 : maxTl * 1.15;
    final interval = top / 4;
    final rodWidth = ((width - 44) / bars.length * 0.6).clamp(4.0, 28.0);
    final labelEvery = math.max(1, (bars.length / 8).ceil());

    return BarChart(
      BarChartData(
        maxY: top,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(_compactTl(value),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                final b = bars[i];
                final force = b.axisLabel.contains('\n');
                if (!force && i % labelEvery != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(b.axisLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary, height: 1.1)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final b = bars[group.x];
              if (b.value == null) return null;
              return BarTooltipItem(
                '${b.tooltipTitle}\n',
                const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    text: CurrencyNormalizer.formatCents(b.value!),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  for (final (label, cents, _) in b.stack)
                    TextSpan(
                      text: '\n$label: ${CurrencyNormalizer.formatCents(cents)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (final (i, b) in bars.indexed)
            BarChartGroupData(
              x: i,
              barRods: b.value == null
                  ? const []
                  : [
                      BarChartRodData(
                        toY: b.value! / 100,
                        width: rodWidth,
                        color: color,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(math.min(6, rodWidth / 2))),
                        rodStackItems: _stackItems(b),
                      ),
                    ],
            ),
        ],
      ),
    );
  }

  static List<BarChartRodStackItem> _stackItems(_Bar b) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final (_, cents, c) in b.stack) {
      final to = from + cents / 100;
      items.add(BarChartRodStackItem(from, to, c));
      from = to;
    }
    return items;
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      );
}

class _Insights extends StatelessWidget {
  const _Insights({required this.picked, required this.allMonths, required this.metric});
  final List<PayslipMonth> picked;
  final List<PayslipMonth> allMonths;
  final PayslipMetric metric;

  @override
  Widget build(BuildContext context) {
    final tax = PayslipAnalyticsService.totalTax(picked);
    final social = PayslipAnalyticsService.totalSocial(picked);
    final rate = PayslipAnalyticsService.effectiveRate(picked);
    final rateMonths = picked.where((m) => m.hasRateData).length;

    // Zam, seçilmemiş komşu aylarla da karşılaştırılabilsin diye tüm geçmişte aranır
    final pickedYears = picked.map((m) => m.year).toSet();
    final raises = PayslipAnalyticsService.detectRaises(allMonths).where((r) => pickedYears.contains(r.year));
    final lastRaise = raises.isEmpty ? null : raises.last;
    final hasWage = PayslipAnalyticsService.hasWageData(allMonths);

    final peakMetric = metric;
    final peak = PayslipAnalyticsService.peakMonth(picked, peakMetric);
    final growth = PayslipAnalyticsService.yearOverYear(picked)
        .where((g) => g.grossPct != null || g.netPct != null)
        .toList();

    final cards = <Widget>[
      _InsightTile(
        icon: Icons.account_balance_rounded,
        color: AppColors.tax,
        label: 'Ödenen vergi',
        value: tax == null ? '—' : CurrencyNormalizer.formatCents(tax),
        note: tax == null
            ? 'Bordrolarda vergi kalemi okunamadı'
            : social == null
                ? 'Gelir + damga vergisi'
                : 'Ayrıca SGK + işsizlik: ${CurrencyNormalizer.formatCents(social)}',
      ),
      _InsightTile(
        icon: Icons.percent_rounded,
        color: AppColors.actionPrimary,
        label: 'Efektif kesinti oranı',
        value: rate == null ? '—' : _pctText(rate),
        note: rate == null ? 'Brüt veya kesinti bilgisi eksik' : 'Yasal kesinti ÷ brüt ($rateMonths ay)',
      ),
      _InsightTile(
        icon: Icons.trending_up_rounded,
        color: AppColors.incomeGreen,
        label: 'Son zam',
        value: lastRaise == null ? '—' : _pctText(lastRaise.pct, signed: true),
        // Zam yalnız bordrodaki ücret satırından; ücret okunamadıysa brütten tahmin yapılmaz
        note: !hasWage
            ? 'Zam tespiti için bordroda ücret satırı gerekli'
            : lastRaise == null
                ? 'Bu aralıkta ücret artışı yok'
                : '${_monthLabel(lastRaise.year, lastRaise.month)} · ücret '
                    '${CurrencyNormalizer.formatCents(lastRaise.fromWageCents)} → '
                    '${CurrencyNormalizer.formatCents(lastRaise.toWageCents)}',
      ),
      _InsightTile(
        icon: Icons.emoji_events_outlined,
        color: _metricColor(peakMetric),
        label: 'En yüksek ay (${peakMetric.label})',
        value: peak == null ? '—' : CurrencyNormalizer.formatCents(peak.valueOf(peakMetric)!),
        note: peak == null ? 'Bu ölçüde veri yok' : _monthLabel(peak.year, peak.month),
      ),
    ];

    return Column(
      children: [
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final card in cards) SizedBox(width: w, child: card)],
          );
        }),
        if (growth.isNotEmpty) ...[
          const SizedBox(height: 10),
          FinanceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yıldan yıla (aylık ortalama)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                for (final g in growth)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${g.fromYear} → ${g.toYear}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        if (g.grossPct != null) _GrowthPill('Brüt', g.grossPct!),
                        if (g.netPct != null) ...[const SizedBox(width: 6), _GrowthPill('Net', g.netPct!)],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GrowthPill extends StatelessWidget {
  const _GrowthPill(this.label, this.pct);
  final String label;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final up = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: up ? AppColors.incomeGreenBg : AppColors.expenseRedBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('$label ${_pctText(pct, signed: true)}',
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800, color: up ? AppColors.incomeGreen : AppColors.expenseRed)),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile(
      {required this.icon, required this.color, required this.label, required this.value, required this.note});
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => FinanceCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ),
            const SizedBox(height: 4),
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
          ],
        ),
      );
}

class _EmptyPayslips extends StatelessWidget {
  const _EmptyPayslips({required this.onUpload});
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: FinanceCard(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Icon(Icons.work_outline_rounded, size: 32, color: AppColors.actionPrimary),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bordro yükleyince maaş ve vergi geçmişin burada görünür',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Net, brüt, vergi ve SGK kesintilerini yıllar boyunca karşılaştırır; zamları ve efektif '
                  'kesinti oranını bordrolarından hesaplar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Bordro yükle (PDF)', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
