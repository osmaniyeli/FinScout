import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/morphing_segmented_bar.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/services/data_changes.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';
import '../../tax_analytics/services/tax_analysis_service.dart';
import '../../fees/services/fee_report_service.dart';
import '../../fees/presentation/fee_period.dart';
import '../../fees/presentation/fee_report_text.dart';
import '../../fees/presentation/fees_view.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final TransactionRepository _repository = TransactionRepository();
  int _selectedTabIndex = 0; // 0: Dağılım, 1: Aylık, 2: Masraflar
  bool _isLoading = false;

  List<Map<String, dynamic>> _categoryShares = [];
  List<Map<String, dynamic>> _monthlyTrends = [];
  int _grandTotalCents = 0;

  // Masraflar: seçili dönem, masraf raporu ve ayrı tutulan tahmini KDV
  FeePeriod _feePeriod = FeePeriod.thisMonth();
  FeeReport? _fees;
  TaxAnalysis? _vat;
  bool _feesLoading = false;
  int _feesRequest = 0; // hızlı dönem değişiminde eski yanıt yenisini ezmesin

  @override
  void initState() {
    super.initState();
    DataChanges.revision.addListener(_loadAnalysisData);
    _loadAnalysisData();
  }

  @override
  void dispose() {
    DataChanges.revision.removeListener(_loadAnalysisData);
    super.dispose();
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final rawCategories = await _repository.getCategorySpendingAnalysis();
      final trends = await _repository.getMonthlyTrendsAnalysis();
      _loadFees();

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
          _grandTotalCents = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFees() async {
    if (!mounted) return;
    final request = ++_feesRequest;
    final period = _feePeriod;
    setState(() => _feesLoading = true);
    try {
      final fees = await FeeReportService()
          .load(year: period.year, month: period.month);
      final vat =
          await TaxAnalysisService().load(from: period.from, to: period.to);
      if (!mounted || request != _feesRequest) return;
      setState(() {
        _fees = fees;
        _vat = vat;
        _feesLoading = false;
      });
    } catch (e) {
      if (!mounted || request != _feesRequest) return;
      setState(() => _feesLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Masraflar yüklenemedi: $e')),
      );
    }
  }

  void _openStatementUpload() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          StatementUploadSheet(onImportSuccess: _loadAnalysisData),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Harcama Analizi',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Video & Shakuro Micro-Interaction: Morflayan Kayan Segment Bar
          MorphingSegmentedBar(
            segments: const ['Dağılım', 'Aylık Trend', 'Masraflar'],
            selectedIndex: _selectedTabIndex,
            onSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
          ),

          // Seçili Sekme İçeriği
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildDistributionTab()
                : (_selectedTabIndex == 1
                    ? _buildMonthlyTrendsTab()
                    : _buildFeesTab()),
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
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
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
                      const Text('Dönem Toplamı:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(cat['amount'] as String,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Toplam Bütçedeki Pay:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text('%${cat['percentage']}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.actionPrimary)),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: const Text('Kapat',
                    style: TextStyle(fontWeight: FontWeight.w700)),
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
        child: FinanceCard(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(icon, size: 32, color: AppColors.actionPrimary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _openStatementUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Banka Ekstresi Yükle (PDF / Excel)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                ),
              ),
            ],
          ),
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
        message:
            'Kategori harcamalarınızı, oranlarını ve tasarruf fırsatlarını görmek için hesap ekstrelerinizi yükleyin.',
      );
    }

    final topCat = _categoryShares.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Donut Grafiği & Gösterge Kartı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kategori Dağılımı',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
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
          FinanceCard(
            padding: const EdgeInsets.all(20),
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
                        strokeWidth: 14,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            topCat['color'] as Color),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Toplam Harcama',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyNormalizer.formatCents(_grandTotalCents)
                                .replaceAll('₺', '')
                                .trim(),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text('TL',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary)),
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
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '%${cat['percentage']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary),
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
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),

          FinanceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: _categoryShares.asMap().entries.map((entry) {
                final idx = entry.key;
                final cat = entry.value;
                final percentage =
                    ((cat['percentage'] as int) / 100.0).clamp(0.02, 1.0);
                final color = cat['color'] as Color;

                return Column(
                  children: [
                    if (idx > 0)
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    InkWell(
                      onTap: () => _showCategoryDetail(cat),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cat['name'] as String,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary),
                                  ),
                                ),
                                Text(
                                  cat['amount'] as String,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareTaxAndExpenseReport,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Raporu paylaş',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareTaxAndExpenseReport() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('FINSCOUT HARCAMA, MASRAF VE TAHMİNİ KDV RAPORU');
      buffer.writeln('Tarih: ${DateTime.now().toLocal()}');
      buffer.writeln('--------------------------------------------------');
      buffer.writeln(
          'Toplam Harcama Hacmi: ${CurrencyNormalizer.formatCents(_grandTotalCents)}');
      buffer.writeln('');
      buffer.writeln('KATEGORİ HARCAMA DAĞILIMI:');
      for (final cat in _categoryShares) {
        buffer.writeln(
            '- ${cat['name']}: ${cat['amount']} (%${cat['percentage']})');
      }
      buffer.writeln('');
      // Masraflar: seçili dönemin gerçek toplamları; KDV ayrı ve "tahmini" etiketli
      final fees = _fees;
      if (fees != null) {
        writeFeeReportSection(buffer,
            period: _feePeriod, report: fees, vat: _vat);
      }
      buffer.writeln('--------------------------------------------------');
      buffer.writeln(
          'FinScout • Bu rapor telefonunda, ekstrelerinden hazırlandı');

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/harcama_ve_masraf_raporu.txt');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        text: 'FinScout Harcama ve Masraf Raporu',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapor paylaşılırken hata: $e')),
        );
      }
    }
  }

  Widget _buildMonthlyTrendsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_monthlyTrends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Aylık Harcama Trendi Bulunmuyor',
        message:
            'Aylar arası harcama ivmesini, ortalamaları ve dönemsel değişimleri analiz etmek için ekstre yükleyin.',
      );
    }

    final int totalCents = _monthlyTrends.fold<int>(
        0, (sum, m) => sum + ((m['cents'] as num?)?.toInt() ?? 0));
    final int avgCents = (_monthlyTrends.isNotEmpty
        ? (totalCents / _monthlyTrends.length).round()
        : 0);
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
          FinanceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DÖNEMLİK AYLIK ORTALAMA',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${_monthlyTrends.length} Ay',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.actionPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${CurrencyNormalizer.formatCents(avgCents)} / ay',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'En yoğun harcama ayı: ${maxMonth['month']} (${CurrencyNormalizer.formatCents((maxMonth['cents'] as num?)?.toInt() ?? 0)})',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Karşılaştırmalı Aylık Sütun Grafiği
          const Text(
            'Aylık Harcama Karşılaştırması',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          FinanceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _monthlyTrends.map((m) {
                    final ratio = ((m['ratio'] as num?)?.toDouble() ?? 0.1)
                        .clamp(0.08, 1.0);
                    final isMax = m == maxMonth;
                    final cents = (m['cents'] as num?)?.toInt() ?? 0;
                    final formatted = CurrencyNormalizer.formatCents(cents)
                        .replaceAll('₺', '')
                        .split(',')[0]
                        .trim();
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          formatted,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMax
                                ? AppColors.actionPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 28,
                          height: 120 * ratio,
                          decoration: BoxDecoration(
                            color: isMax
                                ? AppColors.actionPrimary
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          m['month'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isMax ? FontWeight.w800 : FontWeight.w600,
                            color: isMax
                                ? AppColors.actionPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. İzci Zeka Analitiği
          IzciInsightCard(
            title: "İZCİ AYLIK TREND TESPİTİ",
            message:
                'Aylık harcama tablonuz son ${_monthlyTrends.length} dönemde incelendiğinde harcamaların ${maxMonth['month']} ayında zirveye çıktığı görülüyor. Bir sonraki ayda sabit bütçe disipliniyle tasarruf yaratabilirsiniz.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeesTab() {
    return FeesView(
      period: _feePeriod,
      report: _fees,
      vat: _vat,
      isLoading: _feesLoading,
      onPeriodChanged: (p) {
        if (p == _feePeriod) return;
        setState(() {
          _feePeriod = p;
          _fees = null; // eski dönemin verisi yeni dönem etiketiyle görünmesin
          _vat = null;
        });
        _loadFees();
      },
      onUploadStatement: _openStatementUpload,
      onShare: _shareTaxAndExpenseReport,
    );
  }
}
