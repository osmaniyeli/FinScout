// lib/features/analysis/presentation/analysis_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/dynamic_island_capsule.dart';
import '../../../core/widgets/morphing_segmented_bar.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/config/remote_config_service.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final TransactionRepository _repository = TransactionRepository();
  int _selectedTabIndex = 0; // 0: Dağılım, 1: Aylık, 2: KDV
  bool _showAnalysisCapsule = true;
  bool _isLoading = false;

  List<Map<String, dynamic>> _categoryShares = [];
  List<Map<String, dynamic>> _monthlyTrends = [];
  Map<String, dynamic> _vatSummary = {};
  int _grandTotalCents = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  Color _parseHexColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF64748B);
    }
  }

  Future<void> _loadAnalysisData() async {
    setState(() => _isLoading = true);
    try {
      final rawCategories = await _repository.getCategorySpendingAnalysis();
      final trends = await _repository.getMonthlyTrendsAnalysis();
      final vat = await _repository.getVatAndTaxSummary();

      int total = 0;
      final parsedCats = rawCategories.map((c) {
        final cents = (c['cents'] as int?) ?? 0;
        total += cents;
        return {
          'name': c['name'] as String,
          'percentage': c['percentage'] as int,
          'cents': cents,
          'amount': CurrencyNormalizer.formatCents(cents),
          'color': _parseHexColor((c['color_hex'] as String?) ?? '#64748B'),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _categoryShares = parsedCats;
          _monthlyTrends = trends;
          _vatSummary = vat;
          _grandTotalCents = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openStatementUpload() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatementUploadSheet(onImportSuccess: _loadAnalysisData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Harcama Analizi'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Video & Shakuro Micro-Interaction: Morflayan Kayan Segment Bar
          MorphingSegmentedBar(
            segments: const ['Dağılım', 'Aylık Trend', 'KDV & Fatura'],
            selectedIndex: _selectedTabIndex,
            onSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
          ),

          // Seçili Sekme İçeriği
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildDistributionTab()
                : (_selectedTabIndex == 1 ? _buildMonthlyTrendsTab() : _buildVatTab()),
          ),
        ],
      ),
    );
  }

  void _showCategoryDetail(Map<String, dynamic> cat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
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
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: cat['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${cat['name']} Analitiği',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dönem Toplamı:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(cat['amount'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam Bütçedeki Pay:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text('%${cat['percentage']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.actionPrimary)),
                    ],
                  ),
                ],
              ),
            ),
            // Video 2: Kategori Detay Raporunu Morflayarak Paylaş
            MorphingShareButton(
              fileName: '${(cat['name'] as String).toLowerCase()}_kategori_analizi.pdf',
              label: '${cat['name']} Raporunu İndir & Paylaş',
              accentColor: cat['color'] as Color,
              onDownloadComplete: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('${cat['name']} harcama analizi raporu paylaşıldı.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text('Kapat', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _openStatementUpload,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Banka Ekstresi Yükle (PDF / Excel)', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categoryShares.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Henüz Harcama Dağılımı Oluşmadı',
        message: 'Kategori harcamalarınızı, oranlarını ve tasarruf fırsatlarını görmek için hesap ekstrelerinizi yükleyin.',
      );
    }

    final topCat = _categoryShares.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shakuro Inspired Yüzen Kapsül (%25 Maksimum Boyut, Drag-to-Dismiss)
          if (_showAnalysisCapsule) ...[
            DynamicIslandCapsule(
              title: 'Kategori Harcama Analitiği',
              message:
                  'Bu dönem toplam harcamanızın %${topCat['percentage']}\'i (${topCat['amount']}) ${topCat['name']} kategorisinde gerçekleşti.',
              comparisonHighlight:
                  'Toplam harcama hacmi: ${CurrencyNormalizer.formatCents(_grandTotalCents)}',
              onDismissed: () => setState(() => _showAnalysisCapsule = false),
            ),
            const SizedBox(height: 12),
          ],

          // 1. Donut Grafiği & Gösterge Kartı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kategori Dağılımı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              PulseMetricBadge(
                label: 'LİDER',
                value: '%${topCat['percentage']} ${topCat['name']}',
                pulseColor: topCat['color'] as Color,
                isPositive: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Row(
              children: [
                // Sol: Donut Çemberi
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (topCat['percentage'] as int) / 100.0,
                        strokeWidth: 16,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(topCat['color'] as Color),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Toplam Gider', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyNormalizer.formatCents(_grandTotalCents).replaceAll('₺', '').trim(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text('TL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Sağ: Renk & Yüzde Lejantı
                Expanded(
                  child: Column(
                    children: _categoryShares.take(5).map((cat) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cat['color'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat['name'] as String,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '%${cat['percentage']}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Kategori Dağılım Çubukları
          const Text(
            'Tüm Harcama Kalemleri',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          ..._categoryShares.map((cat) {
            final percentage = ((cat['percentage'] as int) / 100.0).clamp(0.02, 1.0);
            final color = cat['color'] as Color;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: InkWell(
                onTap: () => _showCategoryDetail(cat),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(cat['amount'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 18),

          // Video 2: Morflayan Harcama Dağılımı ve KDV Raporu Paylaşım Butonu
          MorphingShareButton(
            fileName: 'aylik_harcama_ve_kdv_analiz_raporu.pdf',
            label: 'Tüm Harcama & KDV Raporunu İndir & Paylaş',
            accentColor: const Color(0xFF10B981),
            onDownloadComplete: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.incomeGreen,
                  content: Text('Harcama dağılımı ve KDV analitiği raporu hazırlandı ve paylaşıldı.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_monthlyTrends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Aylık Harcama Trendi Bulunmuyor',
        message: 'Aylar arası harcama ivmesini, ortalamaları ve dönemsel değişimleri analiz etmek için ekstre yükleyin.',
      );
    }

    final int totalCents = _monthlyTrends.fold<int>(0, (sum, m) => sum + ((m['cents'] as num?)?.toInt() ?? 0));
    final int avgCents = (_monthlyTrends.isNotEmpty ? (totalCents / _monthlyTrends.length).round() : 0);
    Map<String, dynamic> maxMonth = _monthlyTrends.first;
    for (final m in _monthlyTrends) {
      final cents = (m['cents'] as num?)?.toInt() ?? 0;
      final maxCents = (maxMonth['cents'] as num?)?.toInt() ?? 0;
      if (cents > maxCents) {
        maxMonth = m;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Özet Kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('DÖNEMLİK AYLIK HARCAMA ORTALAMASI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${_monthlyTrends.length} Ay', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${CurrencyNormalizer.formatCents(avgCents)} / ay',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'En yoğun harcama ayı: ${maxMonth['month']} (${CurrencyNormalizer.formatCents((maxMonth['cents'] as num?)?.toInt() ?? 0)})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Karşılaştırmalı Aylık Sütun Grafiği
          const Text(
            'Aylık Harcama Karşılaştırması',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyTrends.map((m) {
                final ratio = ((m['ratio'] as num?)?.toDouble() ?? 0.1).clamp(0.08, 1.0);
                final isMax = m == maxMonth;
                final cents = (m['cents'] as num?)?.toInt() ?? 0;
                final formatted = CurrencyNormalizer.formatCents(cents).replaceAll('₺', '').split(',')[0].trim();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      formatted,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isMax ? AppColors.actionPrimary : AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 120 * ratio,
                      decoration: BoxDecoration(
                        gradient: isMax
                            ? const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF38BDF8)], begin: Alignment.bottomCenter, end: Alignment.topCenter)
                            : const LinearGradient(colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      m['month'] as String? ?? '',
                      style: TextStyle(fontSize: 12, fontWeight: isMax ? FontWeight.w900 : FontWeight.w600, color: isMax ? AppColors.actionPrimary : AppColors.textSecondary),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // 3. İzci Zeka Analitiği
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🦉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('İzci Aylık Trend Tespiti', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF9A3412))),
                      const SizedBox(height: 4),
                      Text(
                        'Aylık harcama tablonuz son ${_monthlyTrends.length} dönemde incelendiğinde harcamaların ${maxMonth['month']} ayında zirveye çıktığı görülüyor. Bir sonraki ayda sabit bütçe disipliniyle tasarruf yaratabilirsiniz.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVatTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final int vatCents = (_vatSummary['vat_cents'] as int?) ?? 0;
    final int deductibleCents = (_vatSummary['deductible_cents'] as int?) ?? 0;
    final int incomeTaxCents = (_vatSummary['income_tax_cents'] as int?) ?? 0;
    final int sgkCents = (_vatSummary['sgk_cents'] as int?) ?? 0;
    final int totalTaxCents = (_vatSummary['total_tax_cents'] as int?) ?? 0;

    if (totalTaxCents == 0 && deductibleCents == 0 && vatCents == 0) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'KDV & Fatura Verisi Bulunmuyor',
        message: 'İçe aktarılan ekstrelerdeki KDV iadeleri ve vergiden düşülebilir harcama kalemleri burada otomatik olarak derlenir.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Devreden / Toplam KDV Yeşil Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF15803D),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Text('TOPLAM / DEVREDEN KDV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 6),
                Text(CurrencyNormalizer.formatCents(vatCents), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('GERÇEK VERİTABANI ANALİTİĞİ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Vergiden Düşülebilir Harcama & Kesintiler
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vergi Matrahı Düşümü', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(CurrencyNormalizer.formatCents(deductibleCents), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.incomeGreen)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Toplam Vergi & Kesinti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(CurrencyNormalizer.formatCents(totalTaxCents), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.expenseRed)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Vergi Detay Kalemleri
          const Text(
            'Vergi & Kesinti Dökümü',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          _buildVatRow('KDV (Katma Değer Vergisi)', CurrencyNormalizer.formatCents(vatCents)),
          _buildVatRow('Gelir Vergisi Tevkifatı', CurrencyNormalizer.formatCents(incomeTaxCents)),
          _buildVatRow('SGK & Diğer Yasal Kesintiler', CurrencyNormalizer.formatCents(sgkCents)),
          _buildVatRow('Vergiden Düşülebilir Harcamalar', CurrencyNormalizer.formatCents(deductibleCents)),
        ],
      ),
    );
  }

  Widget _buildVatRow(String title, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

