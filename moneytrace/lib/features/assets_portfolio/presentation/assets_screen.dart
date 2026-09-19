import 'package:flutter/material.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/services/live_market_service.dart';
import '../../../core/widgets/compact_smart_insight_banner.dart';
import '../../../core/widgets/dynamic_island_capsule.dart';
import '../../../core/widgets/in_app_notification_sheet.dart';
import '../../../core/widgets/morphing_share_button.dart';
import 'widgets/market_news_section.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({Key? key}) : super(key: key);

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final LiveMarketService _marketService = LiveMarketService.instance;
  int _selectedTab = 0; // 0: Birikim, 1: Araç & Mülk, 2: Kartlar

  bool _isLoadingRates = false;
  Map<String, MarketTicker> _marketTickers = {};

  // Portföy Varlıkları
  double _gramGoldQuantity = 10.0;
  int _ceyrekGoldQuantity = 2;
  int _cashTryCents = 50000; // ₺500,00

  // Araç & Konut Varlıkları
  final List<Map<String, dynamic>> _userVehicles = [
    {
      'brand': 'Renault',
      'model': 'Megane 1.5 dCi',
      'year': '2022',
      'fuel_type': 'Dizel',
      'value_cents': 95000000, // ₺950.000,00
      'monthly_cost_cents': 350000, // ₺3.500,00
      'plate': '34 ABC 789',
    }
  ];
  String _selectedHousingType = 'Kiracı (Standart Daire)';
  bool _showEvInsightBanner = true;

  final List<Map<String, dynamic>> _linkedCards = [
    {
      'name': 'Enpara.com Kredi Kartı',
      'mask': '**** 8281',
      'limit': '₺150.000,00',
      'debt': '₺42.580,00',
      'statement_day': 'Her ayın 28\'i',
      'holder': 'Ahmet (Asıl Kart)',
      'is_supplementary': false,
      'color': const Color(0xFF7C3AED),
      'type': 'CREDIT',
    },
    {
      'name': 'Yapı Kredi Worldcard',
      'mask': '**** 4019',
      'limit': '₺200.000,00',
      'debt': '₺56.246,10',
      'statement_day': 'Her ayın 10\'u',
      'holder': 'Eş (Ek Kart)',
      'is_supplementary': true,
      'color': const Color(0xFF0284C7),
      'type': 'CREDIT',
    },
    {
      'name': 'VakıfBank Bankomat TL',
      'mask': '**** 1102',
      'limit': 'Vadesiz TL',
      'debt': '₺12.450,00 (Bakiye)',
      'statement_day': 'Anlık Hesap',
      'holder': 'Ahmet',
      'is_supplementary': false,
      'color': const Color(0xFF10B981),
      'type': 'DEBIT',
    },
  ];

  void _showCardDetail(Map<String, dynamic> card) {
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (card['color'] as Color).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.credit_card_rounded, color: card['color'] as Color, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card['name'] as String,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${card['mask']} • ${card['holder']}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                      const Text('Toplam Limit:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(card['limit'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dönem Borcu / Bakiye:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(card['debt'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.expenseRed)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Hesap Kesim / Yenilenme:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(card['statement_day'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Kart Sahibi Değiştir Butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showReassignHolderDialog(card);
                },
                icon: const Icon(Icons.people_outline_rounded, size: 18, color: AppColors.actionPrimary),
                label: const Text('Kart Sahibini / Aile Üyesini Değiştir', style: TextStyle(color: AppColors.actionPrimary, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _showReassignHolderDialog(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kart Sahibini Ata', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Ahmet (Asıl Kart)', 'Eş (Ek Kart)', 'Çocuk 1 (Harçlık Kartı)', 'Çocuk 2 (Öğrenci Kartı)'].map((h) {
            return ListTile(
              title: Text(h, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              onTap: () {
                setState(() {
                  card['holder'] = h;
                  card['is_supplementary'] = h.contains('Ek') || h.contains('Kartı');
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('${card['name']} kartı "$h" kullanıcısına atandı.'),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddCardDialog() {
    final nameController = TextEditingController();
    final limitController = TextEditingController();
    final maskController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Yeni Kart Ekle / Bağla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Banka / Kart Adı (Örn: Garanti Bonus)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maskController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(labelText: 'Son 4 Hane (Örn: 9182)', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kart Limiti (₺)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final mask = maskController.text.trim();
              final limit = limitController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen kart adını girin.')));
                return;
              }

              setState(() {
                _linkedCards.add({
                  'name': name,
                  'mask': '**** ${mask.isNotEmpty ? mask : "0000"}',
                  'limit': '₺${limit.isNotEmpty ? limit : "50.000"},00',
                  'debt': '₺0,00',
                  'statement_day': 'Her ayın 15\'i',
                  'holder': 'Ahmet (Asıl Kart)',
                  'is_supplementary': false,
                  'color': const Color(0xFF0D9488),
                  'type': 'CREDIT',
                });
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(backgroundColor: AppColors.incomeGreen, content: Text('$name kartı başarıyla bağlandı!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.actionPrimary),
            child: const Text('Bağla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchMarketRates();
  }

  Future<void> _fetchMarketRates() async {
    setState(() => _isLoadingRates = true);
    final rates = await _marketService.fetchLiveRates();
    if (mounted) {
      setState(() {
        _marketTickers = rates;
        _isLoadingRates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Canlı Değer Hesaplama
    final gramGoldPrice = _marketTickers['ALTIN_GR']?.sellingPrice ?? 3045.50;
    final ceyrekGoldPrice = _marketTickers['CEYREK']?.sellingPrice ?? 5010.0;

    final int gramGoldTotalCents = (gramGoldPrice * _gramGoldQuantity * 100).round();
    final int ceyrekGoldTotalCents = (ceyrekGoldPrice * _ceyrekGoldQuantity * 100).round();
    final int vehicleTotalCents = _userVehicles.fold(
        0, (sum, v) => sum + ((v['value_cents'] as num?)?.toInt() ?? 0));
    final int totalWealthCents = gramGoldTotalCents + ceyrekGoldTotalCents + _cashTryCents + vehicleTotalCents;

    final List<Map<String, dynamic>> assets = [
      {
        'title': 'Gram Altın (Kapalıçarşı)',
        'amount': '${_gramGoldQuantity.toStringAsFixed(1)} gr',
        'cost': 'Canlı: ₺${gramGoldPrice.toStringAsFixed(2)}/gr',
        'current_value': CurrencyNormalizer.formatCents(gramGoldTotalCents),
        'icon': Icons.monetization_on_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Çeyrek Altın',
        'amount': '$_ceyrekGoldQuantity Adet',
        'cost': 'Canlı: ₺${ceyrekGoldPrice.toStringAsFixed(0)}/adet',
        'current_value': CurrencyNormalizer.formatCents(ceyrekGoldTotalCents),
        'icon': Icons.circle_rounded,
        'color': const Color(0xFFEAB308),
      },
      {
        'title': 'TL Nakit Cüzdan',
        'amount': 'Nakit',
        'cost': 'Vadesiz TL',
        'current_value': CurrencyNormalizer.formatCents(_cashTryCents),
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.incomeGreen,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Varlıklarım & Portföy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoadingRates
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: AppColors.actionPrimary),
            onPressed: _fetchMarketRates,
            tooltip: 'Kurları Güncelle',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMarketRates,
        color: AppColors.actionPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segment Kontrolcü: [Birikim] | [Kartlar]
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildTabItem('Birikim', 0),
                    _buildTabItem('Araç & Mülk', 1),
                    _buildTabItem('Kartlar', 2),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedTab == 0) ...[
                // Toplam Portföy Büyüklüğü Kartı
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Toplam Varlık Değeri', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyNormalizer.formatCents(totalWealthCents),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniBadge('3 Varlık Kalemi'),
                          const SizedBox(width: 8),
                          _buildMiniBadge('Canlı Piyasa Fiyatlı'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Canlı Kur ve Emtia Bandı (TCMB & Serbest Piyasa)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'CANLI PİYASA KURLARI',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                    ),
                    Text(
                      'Kapalıçarşı & Serbest',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTickerChip('USD/TRY', _marketTickers['USD']?.formattedPrice ?? '₺34,28', _marketTickers['USD']?.changeRate ?? 0.15),
                      _buildTickerChip('EUR/TRY', _marketTickers['EUR']?.formattedPrice ?? '₺37,26', _marketTickers['EUR']?.changeRate ?? -0.08),
                      _buildTickerChip('Gram Altın', _marketTickers['ALTIN_GR']?.formattedPrice ?? '₺3.045,50', _marketTickers['ALTIN_GR']?.changeRate ?? 0.42),
                      _buildTickerChip('Çeyrek Altın', _marketTickers['CEYREK']?.formattedPrice ?? '₺5.010,00', _marketTickers['CEYREK']?.changeRate ?? 0.38),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Varlıklar Listesi
                const Text(
                  'Varlık Portföyüm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),

                ...assets.map((asset) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
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
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (asset['color'] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(asset['icon'] as IconData, color: asset['color'] as Color, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(asset['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(asset['cost'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(asset['amount'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(asset['current_value'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.incomeGreen)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                const MarketNewsSection(),
                const SizedBox(height: 16),

                // Video 2: Morflayan Varlık Portföyü Paylaşım Butonu
                MorphingShareButton(
                  fileName: 'varlik_ve_portfoy_raporu.pdf',
                  label: 'Varlık Portföyünü İndir & Paylaş',
                  accentColor: const Color(0xFFF59E0B),
                  onDownloadComplete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.incomeGreen,
                        content: Text('Varlık ve portföy özeti raporu hazırlandı ve paylaşıldı.'),
                      ),
                    );
                  },
                ),
              ] else if (_selectedTab == 1) ...[
                _buildVehiclesAndPropertyView(),
              ] else ...[
                _buildLinkedCardsView(),
              ],
              const SizedBox(height: 84), // Navigasyon & FAB boşluğu
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehiclesAndPropertyView() {
    final int vehicleTotalCents = _userVehicles.fold(
        0, (sum, v) => sum + ((v['value_cents'] as num?)?.toInt() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shakuro Inspired Yüzen Dynamic Island Kapsülü (%25 Maksimum Boyut, Drag-to-Dismiss)
        if (_showEvInsightBanner)
          DynamicIslandCapsule(
            title: 'Akıllı Tasarruf: Elektrikli Araç Avantajı',
            message:
                'Dizel veya benzinli araçlarda motor yağı, triger, buji, egzoz ve filtre gibi ağır periyodik bakım masrafları bulunurken; elektrikli araçlarda periyodik bakım maliyeti %60-70 daha düşüktür. Evden/işten şarj ile km başına yakıt maliyeti %70-80 daha ekonomiktir.',
            comparisonHighlight:
                'Öneri: Yıllık 20.000 km kullanımda elektrikli araç ile ortalama ₺45.000 - ₺60.000 net tasarruf edebilirsiniz.',
            onDismissed: () => setState(() => _showEvInsightBanner = false),
            onActionTap: () {
              InAppNotificationSheet.show(
                context,
                title: 'Elektrikli Araç Tasarruf Karşılaştırması',
                message:
                    'Dizel/benzinli araçların ağır motor revizyon ve parça maliyetlerine karşılık; elektrikli araç bataryaları 8 yıl/160.000 km garantili olup periyodik bakım giderleri minimumdur.',
              );
            },
          ),

        // Konut & Ev Tipi Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.home_work_rounded, color: AppColors.actionPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('Konut / Ev Durumu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_selectedHousingType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentBlue)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedHousingType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: RemoteConfigService.instance.housingTypes
                    .map((h) => DropdownMenuItem(value: h, child: Text(h, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedHousingType = val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Araç Varlıkları Başlık & Manuel Araç Ekle Butonu
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ARAÇ VARLIKLARI',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                ),
                Text(
                  'Toplam Araç Değeri: ${CurrencyNormalizer.formatCents(vehicleTotalCents)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.incomeGreen),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddVehicleDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Manuel Araç Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Araç Listesi
        ..._userVehicles.map((v) {
          final fuel = v['fuel_type'] as String;
          Color badgeColor = Colors.grey;
          if (fuel == 'Elektrik') badgeColor = const Color(0xFF00D084);
          else if (fuel == 'Dizel') badgeColor = const Color(0xFF475569);
          else if (fuel == 'Benzin') badgeColor = const Color(0xFFF97316);
          else if (fuel == 'Hibrit') badgeColor = const Color(0xFF06B6D4);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.directions_car_rounded, color: badgeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${v['brand']} ${v['model']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(fuel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('${v['year']} Model • Plaka: ${v['plate'] ?? "Belirtilmedi"}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('Aylık Ortalama Bakım/Yakıt: ${CurrencyNormalizer.formatCents((v['monthly_cost_cents'] as num?)?.toInt() ?? 0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE11D48))),
                    ],
                  ),
                ),
                Text(
                  CurrencyNormalizer.formatCents((v['value_cents'] as num?)?.toInt() ?? 0),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showAddVehicleDialog() {
    final brandController = TextEditingController(text: 'Renault');
    final modelController = TextEditingController(text: 'Clio');
    final yearController = TextEditingController(text: '2023');
    final plateController = TextEditingController(text: '34 XYZ 123');
    final valueController = TextEditingController(text: '850000');
    final costController = TextEditingController(text: '3000');
    String selectedFuel = 'Dizel';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: const [
              Icon(Icons.directions_car_filled_rounded, color: AppColors.actionPrimary, size: 22),
              SizedBox(width: 8),
              Text('Manuel Araç Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Marka (Örn: Renault, Fiat, Tesla)')),
                const SizedBox(height: 8),
                TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model (Örn: Megane, Egea, Model Y)')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: yearController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yıl'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: plateController, decoration: const InputDecoration(labelText: 'Plaka'))),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedFuel,
                  decoration: const InputDecoration(labelText: 'Yakıt Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'Benzin', child: Text('Benzin')),
                    DropdownMenuItem(value: 'Dizel', child: Text('Dizel')),
                    DropdownMenuItem(value: 'Elektrik', child: Text('Elektrik')),
                    DropdownMenuItem(value: 'Hibrit', child: Text('Hibrit')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedFuel = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: valueController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Piyasa Değeri (₺)')),
                const SizedBox(height: 8),
                TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Aylık Bakım / Yakıt (₺)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                final brand = brandController.text.trim();
                final model = modelController.text.trim();
                final val = CurrencyNormalizer.toMinorUnits(valueController.text);
                final cost = CurrencyNormalizer.toMinorUnits(costController.text);

                if (brand.isEmpty || model.isEmpty) return;

                setState(() {
                  _userVehicles.add({
                    'brand': brand,
                    'model': model,
                    'year': yearController.text.trim(),
                    'fuel_type': selectedFuel,
                    'value_cents': val > 0 ? val : 75000000,
                    'monthly_cost_cents': cost > 0 ? cost : 250000,
                    'plate': plateController.text.trim(),
                  });
                  if (selectedFuel == 'Dizel' || selectedFuel == 'Benzin') {
                    _showEvInsightBanner = true;
                  }
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('$brand $model aracı portföye eklendi.'),
                  ),
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedCardsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toplam Kart Limiti & Borç Özeti
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('TOPLAM KREDİ KARTI LİMİTİ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                  Text('3 Bağlı Kart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8))),
                ],
              ),
              const SizedBox(height: 6),
              const Text('₺350.000,00', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Dönem Borcu', style: TextStyle(fontSize: 10, color: Color(0xFFFDA4AF))),
                          SizedBox(height: 2),
                          Text('₺98.826,10', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Kullanılabilir Limit', style: TextStyle(fontSize: 10, color: Color(0xFF86EFAC))),
                          SizedBox(height: 2),
                          Text('₺251.173,90', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BAĞLI HESAP & KARTLAR',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            TextButton.icon(
              onPressed: _showAddCardDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Yeni Kart Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ..._linkedCards.map((card) {
          final isCredit = card['type'] == 'CREDIT';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
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
            child: InkWell(
              onTap: () => _showCardDetail(card),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (card['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.credit_card_rounded, color: card['color'] as Color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(card['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              if (card['is_supplementary'] == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Ek Kart', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.actionPrimary)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('${card['mask']} • ${card['holder']} • ${card['statement_day']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(card['debt'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isCredit ? AppColors.expenseRed : AppColors.incomeGreen)),
                        const SizedBox(height: 2),
                        Text(card['limit'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTickerChip(String title, String value, double changeRate) {
    final isPositive = changeRate >= 0;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isPositive ? "+" : ""}${changeRate.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isPositive ? const Color(0xFF166534) : const Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
      ),
    );
  }
}
