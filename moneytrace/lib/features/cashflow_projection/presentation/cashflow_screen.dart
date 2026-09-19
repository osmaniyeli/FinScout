// lib/features/cashflow_projection/presentation/cashflow_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/widgets/dynamic_island_capsule.dart';
import '../../../core/widgets/morphing_segmented_bar.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/widgets/rolling_number_ticker.dart';
import '../models/cashflow_event.dart';
import '../services/cashflow_projection_service.dart';

class CashflowScreen extends StatefulWidget {
  const CashflowScreen({Key? key}) : super(key: key);

  @override
  State<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends State<CashflowScreen> {
  final CashflowProjectionService _projectionService = CashflowProjectionService();

  int _selectedMonthsFilter = 6; // 6 veya 12 ay
  int _salaryDayOfMonth = 15; // Maaş günü
  int _netSalaryCents = 13360000; // ₺133.600,00

  bool _isLoading = false;
  List<CashflowMonthSummary> _projections = [];

  @override
  void initState() {
    super.initState();
    _loadProjections();
  }

  Future<void> _loadProjections() async {
    setState(() => _isLoading = true);
    try {
      final results = await _projectionService.calculateProjections(
        salaryDayOfMonth: _salaryDayOfMonth,
        netSalaryCents: _netSalaryCents,
        numberOfMonths: _selectedMonthsFilter,
      );
      if (mounted) {
        setState(() {
          _projections = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _showCashflowInsight = true;

  void _editSalarySettings() {
    final dayController = TextEditingController(text: _salaryDayOfMonth.toString());
    final salaryController = TextEditingController(
      text: CurrencyNormalizer.formatCents(_netSalaryCents).replaceAll('₺', '').trim(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Maaş & Nakit Akışı Ayarları',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aylık net maaş ve hakediş gününü güncelleyerek gelecek projeksiyonunu yeniden hesaplayın.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dayController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Maaş Günü (1-28)',
                hintText: '15',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: salaryController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Aylık Net Maaş (₺)',
                hintText: '133.600',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),
            // Video 4: Radar Dalgalı Doğrulama ve Güncelleme Butonu
            RadarCheckoutButton(
              label: 'Projeksiyonu Güncelle & Doğrula',
              idleAmountText: '₺${salaryController.text}',
              verifyingAmountText: 'Hesaplanıyor...',
              onPressed: () async {
                await Future.delayed(const Duration(milliseconds: 1400));
                final parsedDay = int.tryParse(dayController.text.trim()) ?? 15;
                final parsedSalary = CurrencyNormalizer.toMinorUnits(salaryController.text.trim());
                setState(() {
                  _salaryDayOfMonth = parsedDay.clamp(1, 28);
                  if (parsedSalary > 0) _netSalaryCents = parsedSalary;
                });
                _loadProjections();
              },
              onVerificationComplete: () {
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Toplam Projeksiyon Metrikleri
    int totalIncome = 0;
    int totalExpense = 0;
    for (final p in _projections) {
      totalIncome += p.projectedIncomeCents;
      totalExpense += p.projectedExpenseCents;
    }
    final int totalNet = totalIncome - totalExpense;
    final int monthlyAverage = _projections.isNotEmpty ? (totalNet / _projections.length).round() : 0;

    final currentMonth = _projections.isNotEmpty ? _projections.first : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nakit Akışı & Gelecek Projeksiyonu',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.actionPrimary),
            onPressed: _editSalarySettings,
            tooltip: 'Maaş Ayarları',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProjections,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shakuro Inspired Yüzen Kapsül (%25 Maksimum Boyut, Drag-to-Dismiss)
                    if (_showCashflowInsight) ...[
                      DynamicIslandCapsule(
                        title: 'Nakit Pisti & Finansal Öngörü',
                        message:
                            'Planlı gelirleriniz önümüzdeki $_selectedMonthsFilter ay boyunca sabit gider ve taksitleri %100 karşılıyor. Kümülatif tasarruf havuzunuz net artış eğilimindedir.',
                        comparisonHighlight:
                            'İpucu: Maaş gününüz her ayın $_salaryDayOfMonth\'i olarak takvime işlenmiştir.',
                        onDismissed: () => setState(() => _showCashflowInsight = false),
                        onActionTap: _editSalarySettings,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Video & Shakuro Micro-Interaction: Morflayan Kayan Dönem Seçici
                    Row(
                      children: [
                        Expanded(
                          child: MorphingSegmentedBar(
                            segments: const ['6 Aylık Plan', '12 Aylık Plan'],
                            selectedIndex: _selectedMonthsFilter == 6 ? 0 : 1,
                            padding: EdgeInsets.zero,
                            height: 38,
                            onSelected: (idx) {
                              setState(() => _selectedMonthsFilter = idx == 0 ? 6 : 12);
                              _loadProjections();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: _editSalarySettings,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDCFCE7)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.incomeGreen),
                                const SizedBox(width: 4),
                                Text(
                                  'Maaş: $_salaryDayOfMonth\'i',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.incomeGreen),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Bu Ayın 30 Günlük Nakit Akışı Kartı
                    if (currentMonth != null) _buildThirtyDayCashflowCard(currentMonth),
                    const SizedBox(height: 16),

                    // 2. Sapma Analitiği & Scout Uyarısı
                    _buildAnomalyInsightCard(),
                    const SizedBox(height: 20),

                    // 3. Projeksiyon Rapor Başlığı & Kart Izgarası
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_selectedMonthsFilter Aylık Kümülatif Bakiye',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const PulseMetricBadge(
                          label: 'CANLI KASA',
                          value: 'PROJEKSİYON',
                          pulseColor: AppColors.actionPrimary,
                          isPositive: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: '$_selectedMonthsFilter ay planlı gider',
                            amountCents: totalExpense,
                            textColor: AppColors.expenseRed,
                            bgColor: const Color(0xFFFFF1F2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: '$_selectedMonthsFilter ay planlı gelir',
                            amountCents: totalIncome,
                            textColor: AppColors.incomeGreen,
                            bgColor: const Color(0xFFF0FDF4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Kümülatif Net Kasa',
                            amountCents: totalNet,
                            textColor: AppColors.actionPrimary,
                            bgColor: const Color(0xFFEFF6FF),
                            prefix: '+',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Aylık Net Tasarruf',
                            amountCents: monthlyAverage,
                            textColor: const Color(0xFF0D9488),
                            bgColor: const Color(0xFFF0FDFA),
                            prefix: '+',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Video 2: Morflayan Projeksiyon Dışa Aktar Butonu (0% -> 100% -> Sosyal Paylaşım)
                    MorphingShareButton(
                      fileName: 'nakit_akisi_projeksiyon_${_selectedMonthsFilter}aylik.pdf',
                      label: '$_selectedMonthsFilter Aylık Projeksiyon Raporunu İndir & Paylaş',
                      accentColor: AppColors.actionPrimary,
                      onDownloadComplete: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.incomeGreen,
                            content: Text('$_selectedMonthsFilter aylık nakit projeksiyon raporu hazırlandı ve paylaşıldı.'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // 4. Gelecek Ayların Taksit & Gelir Takvimi Listesi
                    const Text(
                      'GELECEK AYLARIN TAKVİMİ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ..._projections.map((m) => _buildMonthTimelineTile(m)).toList(),

                    const SizedBox(height: 84), // FAB ve alt navigasyon boşluğu
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, int months) {
    final isSelected = _selectedMonthsFilter == months;
    return InkWell(
      onTap: () {
        setState(() => _selectedMonthsFilter = months);
        _loadProjections();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.actionPrimary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? AppColors.actionPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildThirtyDayCashflowCard(CashflowMonthSummary currentMonth) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.trending_up_rounded, color: AppColors.actionPrimary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Önümüzdeki 30 Günlük Akış',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                currentMonth.monthLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Planlı Gelir & Gider Yan Yana
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Beklenen Gelir', style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyNormalizer.formatCents(currentMonth.projectedIncomeCents),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      const Text('Maaş & Sabit Girişler', style: TextStyle(fontSize: 10, color: Color(0xFF15803D))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kesinleşen Gider', style: TextStyle(fontSize: 11, color: Color(0xFF9F1239), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyNormalizer.formatCents(currentMonth.projectedExpenseCents),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF9F1239)),
                      ),
                      const SizedBox(height: 2),
                      Text('${currentMonth.events.where((e) => !e.isIncome).length} Taksit & Abonelik', style: const TextStyle(fontSize: 10, color: Color(0xFFBE123C))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tahmini Net Etki
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tahmini Ay Sonu Kasası:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  '+${CurrencyNormalizer.formatCents(currentMonth.netBalanceCents)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.actionPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.savings_rounded, color: Color(0xFFEA580C), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'İzci Akış Tüyosu',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF9A3412)),
                ),
                SizedBox(height: 4),
                Text(
                  'Önümüzdeki ay Vatan Bilgisayar taksidi tamamlanıyor! Bütçende açılacak ₺4.258,00 tutarı doğrudan Araç/Ev hedefine aktarabilirsin.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int amountCents,
    required Color textColor,
    required Color bgColor,
    String prefix = '',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor.withOpacity(0.85))),
          const SizedBox(height: 6),
          RollingNumberTicker(
            value: amountCents / 100.0,
            prefix: prefix.isNotEmpty ? '$prefix₺' : '₺',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTimelineTile(CashflowMonthSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summary.monthLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Net: +${CurrencyNormalizer.formatCents(summary.netBalanceCents)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.actionPrimary),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ...summary.events.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: e.isIncome ? const Color(0xFFE6FAF3) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      e.isIncome ? Icons.arrow_downward_rounded : Icons.calendar_today_rounded,
                      size: 16,
                      color: e.isIncome ? AppColors.incomeGreen : AppColors.expenseRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        if (e.subtitle != null)
                          Text(
                            '${e.date.day} ${summary.monthLabel.split(' ')[0]} • ${e.subtitle!}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    (e.isIncome ? '+' : '-') + CurrencyNormalizer.formatCents(e.amountCents),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: e.isIncome ? AppColors.incomeGreen : AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
