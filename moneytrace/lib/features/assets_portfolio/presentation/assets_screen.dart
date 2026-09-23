import 'package:flutter/material.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/services/live_market_service.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/compact_smart_insight_banner.dart';
import '../../../core/widgets/in_app_notification_sheet.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/services/user_profile_service.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';
import 'widgets/market_news_section.dart';
import 'widgets/credit_card_action_sheet.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({Key? key}) : super(key: key);

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final LiveMarketService _marketService = LiveMarketService.instance;
  final TransactionRepository _repository = TransactionRepository();
  int _selectedTab = 0; // 0: Birikim, 1: Araç & Mülk, 2: Kartlar

  bool _isLoadingRates = false;
  Map<String, MarketTicker> _marketTickers = {};

  // Portföy Varlıkları (Temiz Başlangıç)
  double _gramGoldQuantity = 0.0;
  double _gramGoldCostPrice = 0.0; // Alış Maliyeti ₺/gr
  double _gramGoldTargetPrice = 0.0; // Hedef Fiyat ₺/gr

  int _ceyrekGoldQuantity = 0;
  double _ceyrekGoldCostPrice = 0.0; // Alış Maliyeti ₺/adet
  double _ceyrekGoldTargetPrice = 0.0; // Hedef Fiyat ₺/adet

  double _usdQuantity = 0.0;
  double _usdCostPrice = 0.0; // Alış Kuru ₺/$
  double _usdTargetPrice = 0.0; // Hedef Kur ₺/$

  int _cashTryCents = 0;

  // Araç & Konut Varlıkları (Temiz Başlangıç)
  final List<Map<String, dynamic>> _userVehicles = [];
  String _selectedHousingType = 'Kiracı (Standart Daire)';
  bool _showEvInsightBanner = false;

  List<Map<String, dynamic>> _linkedCards = [];

  @override
  void initState() {
    super.initState();
    _loadCardsFromDb();
    _fetchMarketRates();
  }

  Future<void> _loadCardsFromDb() async {
    try {
      final accounts = await _repository.getAccounts();
      if (mounted && accounts.isNotEmpty) {
        setState(() {
          _linkedCards = accounts.map((a) {
            final isCredit =
                (a['account_type'] ?? '').toString().toUpperCase() == 'CREDIT';
            return {
              'name':
                  a['account_name'] ?? a['institution_name'] ?? 'Banka Hesabı',
              'mask': a['card_mask'] ?? '**** 0000',
              'limit': isCredit ? '₺50.000,00' : 'Vadesiz TL',
              'debt': '₺0,00',
              'statement_day': 'Her ayın 15\'i',
              'holder': a['card_holder'] ?? 'Hesap Sahibi',
              'is_supplementary': false,
              'color':
                  isCredit ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
              'type': a['account_type'] ?? 'BANK',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Kartları veritabanından yükleme hatası: $e');
    }
  }

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
                    color: (card['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.credit_card_rounded,
                      color: card['color'] as Color, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card['name'] as String,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      '${card['mask']} • ${card['holder']}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
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
                      const Text('Toplam Limit:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(card['limit'] as String,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Dönem Borcu / Bakiye:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(card['debt'] as String,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.expenseRed)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Hesap Kesim / Yenilenme:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      Text(card['statement_day'] as String,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Kart Limiti & Borç Öde Butonu (Frontend Joe Sliding Card)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  CreditCardActionSheet.show(
                    context,
                    card: card,
                    onCardUpdated: (updated) {
                      setState(() {
                        card['limit'] = updated['limit'];
                        card['debt'] = updated['debt'];
                        card['statement_day'] = updated['statement_day'];
                      });
                    },
                    onDebtPaid: (paidCents, account) async {
                      setState(() {
                        // Kasa borç durumu arayüzde güncellendi
                      });
                      try {
                        await _repository.saveManualTransaction(
                          title: '${card['name']} Kart Borcu Ödemesi',
                          amountCents: paidCents,
                          isExpense: true,
                          categoryId: 'borc_odeme',
                          date: DateTime.now(),
                          note: 'Kart borcu ödemesi - hesap: $account',
                        );
                      } catch (e) {
                        debugPrint('Borç ödeme işlem kaydı hatası: $e');
                      }
                    },
                  );
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: const Text('Borç Öde & Kart Ayarları',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Kart Sahibi Değiştir Butonu
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showReassignHolderDialog(card);
                },
                icon: const Icon(Icons.people_outline_rounded,
                    size: 18, color: AppColors.actionPrimary),
                label: const Text('Kart Sahibini / Aile Üyesini Değiştir',
                    style: TextStyle(
                        color: AppColors.actionPrimary,
                        fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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

  void _showEditCardBalanceDialog(Map<String, dynamic> card) {
    final limitController = TextEditingController(
      text: card['limit']
          .toString()
          .replaceAll('₺', '')
          .replaceAll(',00', '')
          .replaceAll('.', '')
          .trim(),
    );
    final debtController = TextEditingController(
      text: card['debt']
          .toString()
          .replaceAll('₺', '')
          .replaceAll(',00', '')
          .replaceAll('.', '')
          .trim(),
    );
    final dayController = TextEditingController(
        text: card['statement_day']?.toString() ?? 'Her ayın 15\'i');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${card['name']} Düzenle',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Toplam Limit (₺)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: debtController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Güncel Dönem Borcu (₺)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dayController,
                decoration: const InputDecoration(
                    labelText: 'Hesap Kesim / Yenilenme Günü'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final limitText = limitController.text.trim();
              final debtText = debtController.text.trim();
              final dayText = dayController.text.trim();

              final limitCents = CurrencyNormalizer.toMinorUnits(limitText);
              final debtCents = CurrencyNormalizer.toMinorUnits(debtText);

              setState(() {
                if (limitText.isNotEmpty) {
                  card['limit'] = CurrencyNormalizer.formatCents(limitCents);
                }
                if (debtText.isNotEmpty) {
                  card['debt'] = CurrencyNormalizer.formatCents(debtCents);
                }
                if (dayText.isNotEmpty) {
                  card['statement_day'] = dayText;
                }
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.incomeGreen,
                  content: Text(
                      '${card['name']} limit ve bakiye bilgileri güncellendi.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary),
            child: const Text('Kaydet',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showReassignHolderDialog(Map<String, dynamic> card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kart Sahibini Ata',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            '${UserProfileService.instance.profile?.name ?? "Ben"} (Asıl Kart)',
            'Eş (Ek Kart)',
            'Çocuk 1 (Harçlık Kartı)',
            'Çocuk 2 (Öğrenci Kartı)'
          ].map((h) {
            return ListTile(
              title: Text(h,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              onTap: () {
                setState(() {
                  card['holder'] = h;
                  card['is_supplementary'] =
                      h.contains('Ek') || h.contains('Kartı');
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text(
                        '${card['name']} kartı "$h" kullanıcısına atandı.'),
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
        title: const Text('Yeni Kart Ekle / Bağla',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                  labelText: 'Banka / Kart Adı (Örn: Garanti Bonus)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maskController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                  labelText: 'Son 4 Hane (Örn: 9182)', counterText: ''),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final mask = maskController.text.trim();
              final limit = limitController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen kart adını girin.')));
                return;
              }

              setState(() {
                _linkedCards.add({
                  'name': name,
                  'mask': '**** ${mask.isNotEmpty ? mask : "0000"}',
                  'limit': '₺${limit.isNotEmpty ? limit : "50.000"},00',
                  'debt': '₺0,00',
                  'statement_day': 'Her ayın 15\'i',
                  'holder':
                      '${UserProfileService.instance.profile?.name ?? "Ben"} (Asıl Kart)',
                  'is_supplementary': false,
                  'color': const Color(0xFF0D9488),
                  'type': 'CREDIT',
                });
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('$name kartı başarıyla bağlandı!')),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary),
            child: const Text('Bağla',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSelectAssetToEditDialog() {
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
            const Text(
              'Düzenlenecek Varlığı Seçin',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gram, adet, alış maliyeti ve hedef fiyat bilgilerinizi güncelleyin.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFF59E0B)),
              title: const Text('Gram Altın (gr, Maliyet, Hedef)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _showEditAssetDialog('gram_altin');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.circle_rounded, color: Color(0xFFEAB308)),
              title: const Text('Çeyrek Altın (Adet, Maliyet, Hedef)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _showEditAssetDialog('ceyrek_altin');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.attach_money_rounded,
                  color: Color(0xFF10B981)),
              title: const Text('Amerikan Doları / Döviz',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _showEditAssetDialog('usd');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.incomeGreen),
              title: const Text('TL Nakit Bakiye',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                _showEditAssetDialog('nakit_tl');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAssetDialog(String key) {
    String title = '';
    String qtyLabel = 'Miktar';
    String costLabel = 'Alış Birim Maliyeti (₺)';
    String targetLabel = 'Hedef Fiyat (₺)';
    bool showTarget = true;

    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final targetController = TextEditingController();

    if (key == 'gram_altin') {
      title = 'Gram Altın Düzenle';
      qtyLabel = 'Gram Miktarı (gr)';
      costLabel = 'Alış Fiyatı (₺/gr)';
      targetLabel = 'Hedef Satış Fiyatı (₺/gr)';
      if (_gramGoldQuantity > 0)
        qtyController.text = _gramGoldQuantity.toString();
      if (_gramGoldCostPrice > 0)
        costController.text = _gramGoldCostPrice.toString();
      if (_gramGoldTargetPrice > 0)
        targetController.text = _gramGoldTargetPrice.toString();
    } else if (key == 'ceyrek_altin') {
      title = 'Çeyrek Altın Düzenle';
      qtyLabel = 'Adet';
      costLabel = 'Alış Fiyatı (₺/adet)';
      targetLabel = 'Hedef Satış Fiyatı (₺/adet)';
      if (_ceyrekGoldQuantity > 0)
        qtyController.text = _ceyrekGoldQuantity.toString();
      if (_ceyrekGoldCostPrice > 0)
        costController.text = _ceyrekGoldCostPrice.toString();
      if (_ceyrekGoldTargetPrice > 0)
        targetController.text = _ceyrekGoldTargetPrice.toString();
    } else if (key == 'usd') {
      title = 'Amerikan Doları Düzenle';
      qtyLabel = 'Miktar (USD \$)';
      costLabel = 'Alış Kuru (₺/\$)';
      targetLabel = 'Hedef Kur (₺/\$)';
      if (_usdQuantity > 0) qtyController.text = _usdQuantity.toString();
      if (_usdCostPrice > 0) costController.text = _usdCostPrice.toString();
      if (_usdTargetPrice > 0)
        targetController.text = _usdTargetPrice.toString();
    } else {
      title = 'TL Nakit Cüzdan Düzenle';
      qtyLabel = 'Nakit Bakiye (₺)';
      showTarget = false;
      if (_cashTryCents > 0)
        qtyController.text = (_cashTryCents / 100.0).toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: qtyLabel),
              ),
              if (showTarget) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: costLabel),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: targetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: targetLabel,
                    helperText: 'Hedefe ulaşınca bildirim gönderilir',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(
                      qtyController.text.replaceAll(',', '.').trim()) ??
                  0.0;
              final cost = double.tryParse(
                      costController.text.replaceAll(',', '.').trim()) ??
                  0.0;
              final target = double.tryParse(
                      targetController.text.replaceAll(',', '.').trim()) ??
                  0.0;

              setState(() {
                if (key == 'gram_altin') {
                  _gramGoldQuantity = qty;
                  _gramGoldCostPrice = cost;
                  _gramGoldTargetPrice = target;
                  final currentPrice =
                      _marketTickers['ALTIN_GR']?.sellingPrice ?? 3045.50;
                  UserProfileService.instance.checkAssetTargetAlert(
                    assetId: 'gram_altin',
                    assetName: 'Gram Altın',
                    currentPrice: currentPrice,
                    targetPrice: target,
                  );
                } else if (key == 'ceyrek_altin') {
                  _ceyrekGoldQuantity = qty.toInt();
                  _ceyrekGoldCostPrice = cost;
                  _ceyrekGoldTargetPrice = target;
                  final currentPrice =
                      _marketTickers['CEYREK']?.sellingPrice ?? 5010.0;
                  UserProfileService.instance.checkAssetTargetAlert(
                    assetId: 'ceyrek_altin',
                    assetName: 'Çeyrek Altın',
                    currentPrice: currentPrice,
                    targetPrice: target,
                  );
                } else if (key == 'usd') {
                  _usdQuantity = qty;
                  _usdCostPrice = cost;
                  _usdTargetPrice = target;
                  final currentPrice =
                      _marketTickers['USD']?.sellingPrice ?? 34.28;
                  UserProfileService.instance.checkAssetTargetAlert(
                    assetId: 'usd',
                    assetName: 'USD / Dolar',
                    currentPrice: currentPrice,
                    targetPrice: target,
                  );
                } else {
                  _cashTryCents = (qty * 100).round();
                }
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.incomeGreen,
                  content: Text('$title bilgileri başarıyla güncellendi.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary),
            child: const Text('Kaydet',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
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
    final usdPrice = _marketTickers['USD']?.sellingPrice ?? 34.28;

    final int gramGoldTotalCents =
        (gramGoldPrice * _gramGoldQuantity * 100).round();
    final int ceyrekGoldTotalCents =
        (ceyrekGoldPrice * _ceyrekGoldQuantity * 100).round();
    final int usdTotalCents = (usdPrice * _usdQuantity * 100).round();

    final int vehicleTotalCents = _userVehicles.fold(
        0, (sum, v) => sum + ((v['value_cents'] as num?)?.toInt() ?? 0));
    final int totalWealthCents = gramGoldTotalCents +
        ceyrekGoldTotalCents +
        usdTotalCents +
        _cashTryCents +
        vehicleTotalCents;

    // Kâr / Zarar hesapları
    final int gramGoldCostCents =
        (_gramGoldCostPrice * _gramGoldQuantity * 100).round();
    final int gramGoldProfitCents = gramGoldTotalCents - gramGoldCostCents;

    final int ceyrekGoldCostCents =
        (_ceyrekGoldCostPrice * _ceyrekGoldQuantity * 100).round();
    final int ceyrekGoldProfitCents =
        ceyrekGoldTotalCents - ceyrekGoldCostCents;

    final int usdCostCents = (_usdCostPrice * _usdQuantity * 100).round();
    final int usdProfitCents = usdTotalCents - usdCostCents;

    final List<Map<String, dynamic>> assets = [
      {
        'key': 'gram_altin',
        'title': 'Gram Altın (Kapalıçarşı)',
        'amount': '${_gramGoldQuantity.toStringAsFixed(1)} gr',
        'cost': _gramGoldCostPrice > 0
            ? 'Maliyet: ₺${_gramGoldCostPrice.toStringAsFixed(1)} • Hedef: ₺${_gramGoldTargetPrice > 0 ? _gramGoldTargetPrice.toStringAsFixed(0) : "-"}'
            : 'Canlı: ₺${gramGoldPrice.toStringAsFixed(2)}/gr',
        'current_value': CurrencyNormalizer.formatCents(gramGoldTotalCents),
        'profit_text': _gramGoldCostPrice > 0
            ? '${gramGoldProfitCents >= 0 ? "+" : ""}${CurrencyNormalizer.formatCents(gramGoldProfitCents)}'
            : null,
        'is_profit': gramGoldProfitCents >= 0,
        'icon': Icons.monetization_on_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'ceyrek_altin',
        'title': 'Çeyrek Altın',
        'amount': '$_ceyrekGoldQuantity Adet',
        'cost': _ceyrekGoldCostPrice > 0
            ? 'Maliyet: ₺${_ceyrekGoldCostPrice.toStringAsFixed(0)} • Hedef: ₺${_ceyrekGoldTargetPrice > 0 ? _ceyrekGoldTargetPrice.toStringAsFixed(0) : "-"}'
            : 'Canlı: ₺${ceyrekGoldPrice.toStringAsFixed(0)}/adet',
        'current_value': CurrencyNormalizer.formatCents(ceyrekGoldTotalCents),
        'profit_text': _ceyrekGoldCostPrice > 0
            ? '${ceyrekGoldProfitCents >= 0 ? "+" : ""}${CurrencyNormalizer.formatCents(ceyrekGoldProfitCents)}'
            : null,
        'is_profit': ceyrekGoldProfitCents >= 0,
        'icon': Icons.circle_rounded,
        'color': const Color(0xFFEAB308),
      },
      {
        'key': 'usd',
        'title': 'Amerikan Doları (USD)',
        'amount': '\$${_usdQuantity.toStringAsFixed(0)}',
        'cost': _usdCostPrice > 0
            ? 'Maliyet: ₺${_usdCostPrice.toStringAsFixed(2)} • Hedef: ₺${_usdTargetPrice > 0 ? _usdTargetPrice.toStringAsFixed(2) : "-"}'
            : 'Canlı: ₺${usdPrice.toStringAsFixed(2)}/\$',
        'current_value': CurrencyNormalizer.formatCents(usdTotalCents),
        'profit_text': _usdCostPrice > 0
            ? '${usdProfitCents >= 0 ? "+" : ""}${CurrencyNormalizer.formatCents(usdProfitCents)}'
            : null,
        'is_profit': usdProfitCents >= 0,
        'icon': Icons.attach_money_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'key': 'nakit_tl',
        'title': 'TL Nakit Cüzdan',
        'amount': 'Nakit',
        'cost': 'Vadesiz TL',
        'current_value': CurrencyNormalizer.formatCents(_cashTryCents),
        'profit_text': null,
        'is_profit': true,
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.incomeGreen,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Varlıklarım & Portföy',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoadingRates
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded,
                    color: AppColors.actionPrimary),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segment Kontrolcü: [Birikim] | [Araç & Mülk] | [Kartlar]
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
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
                FinanceCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOPLAM PORTFÖY DEĞERİ',
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
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text(
                              'Canlı Değerleme',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.actionPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyNormalizer.formatCents(totalWealthCents),
                        style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniBadge('3 Varlık Kalemi'),
                          const SizedBox(width: 8),
                          _buildMiniBadge('Anlık Kur Takibi'),
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
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5),
                    ),
                    Text(
                      'Kapalıçarşı & Serbest',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTickerChip(
                          'USD/TRY',
                          _marketTickers['USD']?.formattedPrice ?? '₺34,28',
                          _marketTickers['USD']?.changeRate ?? 0.15),
                      _buildTickerChip(
                          'EUR/TRY',
                          _marketTickers['EUR']?.formattedPrice ?? '₺37,26',
                          _marketTickers['EUR']?.changeRate ?? -0.08),
                      _buildTickerChip(
                          'Gram Altın',
                          _marketTickers['ALTIN_GR']?.formattedPrice ??
                              '₺3.045,50',
                          _marketTickers['ALTIN_GR']?.changeRate ?? 0.42),
                      _buildTickerChip(
                          'Çeyrek Altın',
                          _marketTickers['CEYREK']?.formattedPrice ??
                              '₺5.010,00',
                          _marketTickers['CEYREK']?.changeRate ?? 0.38),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Varlıklar Listesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Varlık Portföyüm',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: () => _showSelectAssetToEditDialog(),
                      icon: const Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.actionPrimary),
                      label: const Text('Varlıkları Düzenle',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.actionPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                FinanceCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: assets.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final asset = entry.value;
                      return Column(
                        children: [
                          if (idx > 0)
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          InkWell(
                            onTap: () =>
                                _showEditAssetDialog(asset['key'] as String),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: (asset['color'] as Color)
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Icon(asset['icon'] as IconData,
                                        color: asset['color'] as Color,
                                        size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(asset['title'] as String,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text(asset['cost'] as String,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(asset['amount'] as String,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(asset['current_value'] as String,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.incomeGreen)),
                                      if (asset['profit_text'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'K/Z: ${asset['profit_text']}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: asset['is_profit'] == true
                                                ? AppColors.incomeGreen
                                                : AppColors.expenseRed,
                                          ),
                                        ),
                                      ],
                                    ],
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
                const SizedBox(height: 16),
                const MarketNewsSection(),
                const SizedBox(height: 16),

                // Video 2: Morflayan Varlık Portföyü Paylaşım Butonu
                MorphingShareButton(
                  fileName: 'varlik_ve_portfoy_raporu.pdf',
                  label: 'Varlık Portföyünü İndir & Paylaş',
                  accentColor: AppColors.actionPrimary,
                  onDownloadComplete: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.incomeGreen,
                        content: Text(
                            'Varlık ve portföy özeti raporu hazırlandı ve paylaşıldı.'),
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
        // Konut & Ev Tipi Kartı
        FinanceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.home_work_rounded,
                          color: AppColors.actionPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('Konut / Ev Durumu',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(_selectedHousingType,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.actionPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedHousingType,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
                items: RemoteConfigService.instance.housingTypes
                    .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text(h,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600))))
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
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5),
                ),
                Text(
                  'Toplam Araç Değeri: ${CurrencyNormalizer.formatCents(vehicleTotalCents)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.incomeGreen),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddVehicleDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Manuel Araç Ekle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Araç Listesi
        if (_userVehicles.isEmpty)
          FinanceCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 36, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  const Text('Henüz Kayıtlı Araç Bulunmuyor',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text(
                      'Aracınızı ekleyerek kasko, yakıt ve bakım giderlerini takip edebilirsiniz.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddVehicleDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('İlk Aracını Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._userVehicles.map((v) {
            final fuel = v['fuel_type'] as String;
            Color badgeColor = Colors.grey;
            if (fuel == 'Elektrik')
              badgeColor = const Color(0xFF00D084);
            else if (fuel == 'Dizel')
              badgeColor = const Color(0xFF475569);
            else if (fuel == 'Benzin')
              badgeColor = const Color(0xFFF97316);
            else if (fuel == 'Hibrit') badgeColor = const Color(0xFF06B6D4);

            return FinanceCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.directions_car_rounded,
                        color: badgeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${v['brand']} ${v['model']}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(fuel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: badgeColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                            '${v['year']} Model • Plaka: ${v['plate'] ?? "Belirtilmedi"}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                            'Aylık Bakım/Yakıt: ${CurrencyNormalizer.formatCents((v['monthly_cost_cents'] as num?)?.toInt() ?? 0)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE11D48))),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyNormalizer.formatCents(
                        (v['value_cents'] as num?)?.toInt() ?? 0),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: const [
              Icon(Icons.directions_car_filled_rounded,
                  color: AppColors.actionPrimary, size: 22),
              SizedBox(width: 8),
              Text('Manuel Araç Ekle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: brandController,
                    decoration: const InputDecoration(
                        labelText: 'Marka (Örn: Renault, Fiat, Tesla)')),
                const SizedBox(height: 8),
                TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                        labelText: 'Model (Örn: Megane, Egea, Model Y)')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Yıl'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: plateController,
                            decoration:
                                const InputDecoration(labelText: 'Plaka'))),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedFuel,
                  decoration: const InputDecoration(labelText: 'Yakıt Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'Benzin', child: Text('Benzin')),
                    DropdownMenuItem(value: 'Dizel', child: Text('Dizel')),
                    DropdownMenuItem(
                        value: 'Elektrik', child: Text('Elektrik')),
                    DropdownMenuItem(value: 'Hibrit', child: Text('Hibrit')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedFuel = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Piyasa Değeri (₺)')),
                const SizedBox(height: 8),
                TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Aylık Bakım / Yakıt (₺)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                final brand = brandController.text.trim();
                final model = modelController.text.trim();
                final val =
                    CurrencyNormalizer.toMinorUnits(valueController.text);
                final cost =
                    CurrencyNormalizer.toMinorUnits(costController.text);

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
    if (_linkedCards.isEmpty) {
      return FinanceCard(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.actionPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    size: 28, color: AppColors.actionPrimary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Henüz Bağlı Kart veya Hesap Yok',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ekstre PDF\'lerinizi yüklediğinizde banka hesaplarınız ve kartlarınız otomatik olarak burada listelenir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      StatementUploadSheet.show(context);
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Ekstre Yükle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _showAddCardDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Manuel Ekle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toplam Kart Limiti & Borç Özeti
        FinanceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOPLAM HESAP & KARTLAR',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.actionPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('${_linkedCards.length} Bağlı Hesap',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.actionPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${_linkedCards.length} Aktif Kart / Cüzdan',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.incomeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Cihaz İçi Kriptolu • Sıfır-Bilgi',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    const Text('Güvenli',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.incomeGreen)),
                  ],
                ),
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
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5),
            ),
            TextButton.icon(
              onPressed: _showAddCardDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Yeni Kart Ekle',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ..._linkedCards.map((card) {
          final isCredit = card['type'] == 'CREDIT';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: FinanceCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _showCardDetail(card),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color:
                              (card['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.credit_card_rounded,
                            color: card['color'] as Color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(card['name'] as String,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary)),
                                if (card['is_supplementary'] == true) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Ek Kart',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.actionPrimary)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                                '${card['mask']} • ${card['holder']} • ${card['statement_day']}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(card['debt'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isCredit
                                      ? AppColors.expenseRed
                                      : AppColors.incomeGreen)),
                          const SizedBox(height: 2),
                          Text(card['limit'] as String,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.textMuted),
                    ],
                  ),
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
              Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isPositive ? "+" : ""}${changeRate.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isPositive
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B)),
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
                      color: Colors.black.withValues(alpha: 0.04),
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
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
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
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary),
      ),
    );
  }
}
