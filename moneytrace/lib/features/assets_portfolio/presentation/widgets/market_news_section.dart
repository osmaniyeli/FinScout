// lib/features/assets_portfolio/presentation/widgets/market_news_section.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/market_news_item.dart';
import '../../../../core/services/market_news_service.dart';
import '../../../../core/widgets/remote_feature_gate.dart';
import '../../../../core/widgets/pulse_metric_badge.dart';

class MarketNewsSection extends StatefulWidget {
  const MarketNewsSection({Key? key}) : super(key: key);

  @override
  State<MarketNewsSection> createState() => _MarketNewsSectionState();
}

class _MarketNewsSectionState extends State<MarketNewsSection> {
  final MarketNewsService _newsService = MarketNewsService.instance;
  bool _isLoading = false;
  List<MarketNewsItem> _news = [];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final items = await _newsService.fetchNews(forceRefresh: forceRefresh);

    if (mounted) {
      setState(() {
        _news = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemoteFeatureGate(
      moduleKey: 'market_news',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Video Micro-Interaction: Canlılık Radarı İndikatörü
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const PulseMetricBadge(
                label: 'CANLI AKIŞ',
                value: 'PİYASA GÜNDEMİ',
                pulseColor: Color(0xFF10B981),
                isPositive: true,
              ),
              InkWell(
                onTap: () => _loadNews(forceRefresh: true),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.sync_rounded,
                            size: 14, color: AppColors.actionPrimary),
                      const SizedBox(width: 4),
                      const Text(
                        'Yenile',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.actionPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Kaynak: Bloomberg HT & Dünya Gazetesi (Resmi RSS)',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Haber Kartları
          if (_news.isEmpty && _isLoading)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.actionPrimary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _news.length > 5 ? 5 : _news.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _news[index];
                return _buildNewsCard(context, item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, MarketNewsItem item) {
    final isBloomberg = item.sourceName.contains('Bloomberg');
    final sourceColor =
        isBloomberg ? const Color(0xFF1E3A8A) : const Color(0xFF047857);
    final sourceBgColor =
        isBloomberg ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);

    return InkWell(
      onTap: () => _showNewsDetailModal(context, item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Kaynak Rozeti + Kategori + Süre
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sourceBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: sourceColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    item.sourceName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: sourceColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.category,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B)),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      item.timeAgoFormatted,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Haber Başlığı
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Haber Özeti
            Text(
              item.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewsDetailModal(BuildContext context, MarketNewsItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Kaynak & Saat
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.sourceName,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.timeAgoFormatted,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tam Başlık
              Text(
                item.title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.3),
              ),
              const SizedBox(height: 14),

              // Tam Özet / İçerik
              Text(
                item.summary,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF334155), height: 1.5),
              ),
              const SizedBox(height: 20),

              // Telif / Yasal Uyarı
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kaynak: ${item.sourceName} resmi açık RSS akışı. Tüm telif ve yayın hakları kaynağa aittir.',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Orijinal Habere Git Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (item.link.isNotEmpty) {
                      final uri = Uri.parse(item.link);
                      try {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } catch (_) {
                        await launchUrl(uri);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Haberi Orijinal Kaynağından Aç',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
