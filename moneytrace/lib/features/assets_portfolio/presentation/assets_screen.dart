import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/services/live_market_service.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../data/vehicle_catalog.dart';
import '../repositories/assets_repository.dart';
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
  List<Map<String, dynamic>> _userVehicles = [];
  String _selectedHousingType = 'Kiracı (Standart Daire)';

  final AssetsRepository _assets = AssetsRepository.instance;
  List<Map<String, dynamic>> _linkedCards = [];
  List<String> _paymentSourceAccounts = const ['Nakit Cüzdan'];

  static const List<String> _bankNames = [
    'Akbank',
    'Albaraka Türk',
    'Burgan Bank',
    'CEPTETEB',
    'DenizBank',
    'Enpara',
    'Fibabanka',
    'Garanti BBVA',
    'Halkbank',
    'HSBC',
    'ING',
    'İş Bankası',
    'Kuveyt Türk',
    'Odeabank',
    'QNB',
    'Şekerbank',
    'TEB',
    'Türkiye Finans',
    'VakıfBank',
    'Vakıf Katılım',
    'Yapı Kredi',
    'Ziraat Bankası',
    'Ziraat Katılım',
  ];

  @override
  void initState() {
    super.initState();
    _loadPersistedAssets();
    _fetchMarketRates();
  }

  /// Elle girilen varlıkları (altın/döviz/nakit, konut, araçlar) cihazdan geri yükler.
  Future<void> _loadPersistedAssets() async {
    await _assets.load();
    if (!mounted) return;
    final gram = _assets.holding('gram_altin');
    final ceyrek = _assets.holding('ceyrek_altin');
    final usd = _assets.holding('usd');
    final cash = _assets.holding('nakit_tl');
    final housing = _assets.housingType;
    setState(() {
      _gramGoldQuantity = gram['quantity']!;
      _gramGoldCostPrice = gram['cost']!;
      _gramGoldTargetPrice = gram['target']!;
      _ceyrekGoldQuantity = ceyrek['quantity']!.toInt();
      _ceyrekGoldCostPrice = ceyrek['cost']!;
      _ceyrekGoldTargetPrice = ceyrek['target']!;
      _usdQuantity = usd['quantity']!;
      _usdCostPrice = usd['cost']!;
      _usdTargetPrice = usd['target']!;
      _cashTryCents = (cash['quantity']! * 100).round();
      if (RemoteConfigService.instance.housingTypes.contains(housing)) {
        _selectedHousingType = housing;
      }
      _userVehicles = _assets.vehicles;
    });
    await _loadCardsFromDb();
    await _syncVehicleReminders();
  }

  /// Banka adlarını eşleştirme için sadeleştirir: "Türkiye İş Bankası A.Ş." → "is", "Garanti BBVA" → "garantibbva".
  static String _foldBank(String name) {
    const tr = {
      'ı': 'i',
      'İ': 'i',
      'I': 'i',
      'ş': 's',
      'Ş': 's',
      'ğ': 'g',
      'Ğ': 'g',
      'ü': 'u',
      'Ü': 'u',
      'ö': 'o',
      'Ö': 'o',
      'ç': 'c',
      'Ç': 'c'
    };
    final b = StringBuffer();
    for (final ch in name.split('')) {
      b.write(tr[ch] ?? ch.toLowerCase());
    }
    return b
        .toString()
        .replaceAll(
            RegExp(r'\b(turkiye|bankasi|bank|a\.?s\.?|t\.?a\.?s\.?|ve)\b'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _sameBank(String a, String b) {
    final x = _foldBank(a), y = _foldBank(b);
    if (x.isEmpty || y.isEmpty) return false;
    if (x == y) return true;
    final shorter = x.length <= y.length ? x : y;
    final longer = identical(shorter, x) ? y : x;
    return shorter.length >= 3 && longer.contains(shorter);
  }

  static String? _formatIsoDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Ekstresi yüklenen hesaplar + elle eklenen kartlar. Borç/son ödeme yalnızca bankanın ekstresinden,
  /// limit yalnızca kullanıcının girdiği manuel karttan gelir. Manuel kart aynı bankanın kredi kartı
  /// ekstresi gelince otomatik eşleşir; eşleşmeyen manuel kart "ekstre bekleniyor" olarak görünür.
  Future<void> _loadCardsFromDb() async {
    try {
      final accounts = await _repository.getAccountsWithLatestStatement();
      final manual = _assets.manualCards;
      final used = <String>{};
      final ownerName =
          '${UserProfileService.instance.profile?.name ?? "Ben"} (Asıl Kart)';
      final cards = <Map<String, dynamic>>[];

      for (final a in accounts) {
        final isCredit = a['account_type'] == 'CREDIT_CARD';
        final bank = (a['institution_name'] as String?) ?? 'Banka';
        Map<String, dynamic>? match;
        if (isCredit) {
          for (final m in manual) {
            if (!used.contains(m['id']) &&
                _sameBank(bank, (m['bank'] as String?) ?? '')) {
              match = m;
              used.add(m['id'] as String);
              break;
            }
          }
        }
        final balance = (a['statement_balance_cents'] as num?)?.toInt();
        final due = _formatIsoDate(a['due_date'] as String?);
        final limitCents = (match?['limit_cents'] as num?)?.toInt();
        final mask = (a['card_mask'] as String?) ?? '';
        final holder = (a['card_holder'] as String?) ?? '';
        cards.add({
          'name': bank,
          'bank': bank,
          'mask': mask.isNotEmpty
              ? mask
              : (isCredit ? 'Kredi Kartı' : 'Vadesiz Hesap'),
          'limit': isCredit
              ? (limitCents != null
                  ? CurrencyNormalizer.formatCents(limitCents)
                  : 'Limit girilmedi')
              : 'Vadesiz Hesap',
          'debt':
              balance != null ? CurrencyNormalizer.formatCents(balance) : '—',
          'statement_day': due != null
              ? 'Son ödeme $due'
              : (isCredit ? 'Son ödeme —' : 'Hesap ekstresi'),
          'holder': holder.isNotEmpty ? holder : ownerName,
          'is_supplementary': false,
          'color': isCredit ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
          'type': isCredit ? 'CREDIT_CARD' : 'CHECKING',
          'manual_id': match?['id'],
        });
      }

      for (final m in manual.where((m) => !used.contains(m['id']))) {
        cards.add({
          'name': m['bank'],
          'bank': m['bank'],
          'mask': 'Ekstre bekleniyor',
          'limit': CurrencyNormalizer.formatCents(
              (m['limit_cents'] as num?)?.toInt() ?? 0),
          'debt': '—',
          'statement_day': 'İlk ekstre yüklenince eşleşir',
          'holder': ownerName,
          'is_supplementary': false,
          'color': const Color(0xFF0D9488),
          'type': 'CREDIT_CARD',
          'manual_id': m['id'],
        });
      }

      final sources = <String>{
        'Nakit Cüzdan',
        ...accounts
            .where((a) => a['account_type'] == 'CHECKING')
            .map((a) => '${a['institution_name']} Vadesiz'),
      }.toList();

      if (mounted) {
        setState(() {
          _linkedCards = cards;
          _paymentSourceAccounts = sources;
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
            if (card['type'] == 'CREDIT_CARD')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    CreditCardActionSheet.show(
                      context,
                      card: card,
                      sourceAccounts: _paymentSourceAccounts,
                      onCardUpdated: (updated) async {
                        // Limit kullanıcıya ait bilgi → manuel karta yazılır; borç ve son ödeme ekstreden gelir.
                        final limitCents = CurrencyNormalizer.toMinorUnits(
                            updated['limit'].toString());
                        if (limitCents > 0) {
                          await _assets.upsertManualCard({
                            'id': card['manual_id'] ??
                                'mc_${DateTime.now().millisecondsSinceEpoch}',
                            'bank': card['bank'] ?? card['name'],
                            'limit_cents': limitCents,
                          });
                        }
                        await _loadCardsFromDb();
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
                            txKind: 'CARDPAYMENT',
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
            if (card['manual_id'] != null) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _assets.deleteManualCard(card['manual_id'] as String);
                    await _loadCardsFromDb();
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.expenseRed),
                  label: const Text('Manuel kart bilgisini sil',
                      style: TextStyle(
                          color: AppColors.expenseRed,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
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
    final limitController = TextEditingController();
    final otherBankController = TextEditingController();
    String? selectedBank;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Kredi Kartı Ekle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedBank,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Banka'),
                  items: [..._bankNames, 'Diğer']
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setModalState(() => selectedBank = v),
                ),
                if (selectedBank == 'Diğer') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherBankController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Banka adı'),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration:
                      const InputDecoration(labelText: 'Kart Limiti (₺)'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bu bankanın kredi kartı ekstresini yüklediğinde kart otomatik eşleşir; '
                  'dönem borcu ve son ödeme tarihi ekstreden okunur.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final bank = selectedBank == 'Diğer'
                    ? otherBankController.text.trim()
                    : (selectedBank ?? '');
                final limitCents =
                    CurrencyNormalizer.toMinorUnits(limitController.text);
                if (bank.isEmpty || limitCents <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Banka ve kart limitini girin.')));
                  return;
                }
                Navigator.pop(ctx);
                await _assets.upsertManualCard({
                  'id': 'mc_${DateTime.now().millisecondsSinceEpoch}',
                  'bank': bank,
                  'limit_cents': limitCents,
                });
                await _loadCardsFromDb();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('$bank kartı eklendi.')));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary),
              child: const Text('Ekle',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
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
                      _marketTickers['ALTIN_GR']?.sellingPrice ?? 0.0;
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
                      _marketTickers['CEYREK']?.sellingPrice ?? 0.0;
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
                      _marketTickers['USD']?.sellingPrice ?? 0.0;
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
              _assets.setHolding(key,
                  quantity: qty, cost: cost, target: target);

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
    final gramGoldPrice = _marketTickers['ALTIN_GR']?.sellingPrice ?? 0.0;
    final ceyrekGoldPrice = _marketTickers['CEYREK']?.sellingPrice ?? 0.0;
    final usdPrice = _marketTickers['USD']?.sellingPrice ?? 0.0;

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

                // Canlı Kur ve Emtia Bandı (serbest piyasa)
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
                          _marketTickers['USD']?.formattedPrice ?? '—',
                          _marketTickers['USD']?.changeRate ?? 0),
                      _buildTickerChip(
                          'EUR/TRY',
                          _marketTickers['EUR']?.formattedPrice ?? '—',
                          _marketTickers['EUR']?.changeRate ?? 0),
                      _buildTickerChip(
                          'Gram Altın',
                          _marketTickers['ALTIN_GR']?.formattedPrice ?? '—',
                          _marketTickers['ALTIN_GR']?.changeRate ?? 0),
                      _buildTickerChip(
                          'Çeyrek Altın',
                          _marketTickers['CEYREK']?.formattedPrice ?? '—',
                          _marketTickers['CEYREK']?.changeRate ?? 0),
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
                  if (val != null) {
                    setState(() => _selectedHousingType = val);
                    _assets.setHousingType(val);
                  }
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
              onPressed: () => _showVehicleDialog(),
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
                    onPressed: () => _showVehicleDialog(),
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

            final km = (v['km'] as num?)?.toInt() ?? 0;
            final updated = _formatIsoDate(v['updated_at'] as String?);
            return FinanceCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _showVehicleDialog(existing: v),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
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
                                [
                                  if ((v['year'] ?? '').toString().isNotEmpty)
                                    '${v['year']} Model',
                                  if (km > 0)
                                    '${ThousandsInputFormatter.format('$km')} km',
                                  if ((v['plate'] ?? '').toString().isNotEmpty)
                                    '${v['plate']}',
                                ].join(' • '),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            if (((v['monthly_cost_cents'] as num?)?.toInt() ??
                                    0) >
                                0)
                              Text(
                                  'Aylık Bakım/Yakıt: ${CurrencyNormalizer.formatCents((v['monthly_cost_cents'] as num).toInt())}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFE11D48))),
                            if (updated != null)
                              Text('Değer güncellemesi: $updated',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted)),
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
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  static String _digitsOf(Object? cents) {
    final c = (cents as num?)?.toInt() ?? 0;
    return c > 0 ? ThousandsInputFormatter.format('${c ~/ 100}') : '';
  }

  /// Araç ekleme / güncelleme. Alanlar boş gelir; marka ve model listeden seçilir.
  void _showVehicleDialog({Map<String, dynamic>? existing}) {
    String? brand = existing?['brand'] as String?;
    String? model = existing?['model'] as String?;
    if (brand != null && !VehicleCatalog.brands.containsKey(brand)) {
      brand = VehicleCatalog.other;
    }
    if (brand != null &&
        brand != VehicleCatalog.other &&
        model != null &&
        !VehicleCatalog.modelsOf(brand).contains(model)) {
      model = VehicleCatalog.other;
    }
    final customBrandController = TextEditingController(
        text: brand == VehicleCatalog.other
            ? (existing?['brand'] as String?)
            : '');
    final customModelController = TextEditingController(
        text: model == VehicleCatalog.other
            ? (existing?['model'] as String?)
            : '');
    final yearController =
        TextEditingController(text: (existing?['year'] ?? '').toString());
    final plateController =
        TextEditingController(text: (existing?['plate'] ?? '').toString());
    final km = (existing?['km'] as num?)?.toInt() ?? 0;
    final kmController = TextEditingController(
        text: km > 0 ? ThousandsInputFormatter.format('$km') : '');
    final valueController =
        TextEditingController(text: _digitsOf(existing?['value_cents']));
    final costController =
        TextEditingController(text: _digitsOf(existing?['monthly_cost_cents']));
    String? selectedFuel = existing?['fuel_type'] as String?;
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.directions_car_filled_rounded,
                  color: AppColors.actionPrimary, size: 22),
              const SizedBox(width: 8),
              Text(isEdit ? 'Aracı Güncelle' : 'Araç Ekle',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: brand,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Marka'),
                  items: VehicleCatalog.brandNames
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setModalState(() {
                    brand = v;
                    model = null;
                  }),
                ),
                if (brand == VehicleCatalog.other) ...[
                  const SizedBox(height: 8),
                  TextField(
                      controller: customBrandController,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Marka adı')),
                ],
                if (brand != null) ...[
                  const SizedBox(height: 8),
                  if (brand != VehicleCatalog.other)
                    DropdownButtonFormField<String>(
                      key: ValueKey('model_$brand'),
                      initialValue: model,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Model'),
                      items: VehicleCatalog.modelsOf(brand!)
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) => setModalState(() => model = v),
                    ),
                  if (brand == VehicleCatalog.other ||
                      model == VehicleCatalog.other)
                    TextField(
                        controller: customModelController,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Model adı')),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(
                                labelText: 'Model yılı', counterText: ''))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                                labelText: 'Plaka (isteğe bağlı)'))),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedFuel,
                  decoration: const InputDecoration(labelText: 'Yakıt Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'Benzin', child: Text('Benzin')),
                    DropdownMenuItem(value: 'Dizel', child: Text('Dizel')),
                    DropdownMenuItem(value: 'LPG', child: Text('LPG')),
                    DropdownMenuItem(
                        value: 'Elektrik', child: Text('Elektrik')),
                    DropdownMenuItem(value: 'Hibrit', child: Text('Hibrit')),
                  ],
                  onChanged: (val) => setModalState(() => selectedFuel = val),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: kmController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: const InputDecoration(labelText: 'Kilometre')),
                const SizedBox(height: 8),
                TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: const InputDecoration(
                        labelText: 'Güncel Piyasa Değeri (₺)')),
                const SizedBox(height: 8),
                TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: const InputDecoration(
                        labelText: 'Aylık Bakım / Yakıt (₺, isteğe bağlı)')),
                const SizedBox(height: 10),
                const Text(
                  '6 ayda bir piyasa değerini ve kilometreyi güncellemen için hatırlatma gönderilir.',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final id = existing['id'] as String;
                  await _assets.deleteVehicle(id);
                  await NotificationService.instance
                      .cancel(NotificationService.stableId('vehicle|$id'));
                  if (mounted) setState(() => _userVehicles = _assets.vehicles);
                },
                child: const Text('Sil',
                    style: TextStyle(color: AppColors.expenseRed)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final brandName = brand == VehicleCatalog.other
                    ? customBrandController.text.trim()
                    : (brand ?? '');
                final modelName = (brand == VehicleCatalog.other ||
                        model == VehicleCatalog.other)
                    ? customModelController.text.trim()
                    : (model ?? '');
                final valueCents =
                    CurrencyNormalizer.toMinorUnits(valueController.text);
                if (brandName.isEmpty ||
                    modelName.isEmpty ||
                    selectedFuel == null ||
                    valueCents <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Marka, model, yakıt tipi ve piyasa değerini girin.')));
                  return;
                }
                final vehicle = <String, dynamic>{
                  'id': existing?['id'] ??
                      'veh_${DateTime.now().millisecondsSinceEpoch}',
                  'brand': brandName,
                  'model': modelName,
                  'year': yearController.text.trim(),
                  'plate': plateController.text.trim(),
                  'fuel_type': selectedFuel,
                  'km':
                      int.tryParse(kmController.text.replaceAll('.', '')) ?? 0,
                  'value_cents': valueCents,
                  'monthly_cost_cents':
                      CurrencyNormalizer.toMinorUnits(costController.text),
                  'updated_at': DateTime.now().toIso8601String(),
                };
                Navigator.pop(ctx);
                await _assets.upsertVehicle(vehicle);
                await NotificationService.instance.requestPermission();
                await _scheduleVehicleReminder(vehicle);
                if (!mounted) return;
                setState(() => _userVehicles = _assets.vehicles);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text(isEdit
                        ? '$brandName $modelName güncellendi.'
                        : '$brandName $modelName portföye eklendi.'),
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

  /// Son güncellemeden 6 ay sonrası için "değer ve km güncelle" bildirimi (aynı id → tekrar kurulunca yerini alır).
  Future<void> _scheduleVehicleReminder(Map<String, dynamic> v) async {
    final updated =
        DateTime.tryParse((v['updated_at'] as String?) ?? '') ?? DateTime.now();
    final when = DateTime(updated.year, updated.month + 6, updated.day, 10);
    try {
      await NotificationService.instance.scheduleOneShot(
        id: NotificationService.stableId('vehicle|${v['id']}'),
        title: 'Aracının değerini güncelle',
        body:
            '${v['brand']} ${v['model']} için güncel piyasa değerini ve kilometreyi gir; varlık toplamın doğru kalsın.',
        when: when,
      );
    } catch (e) {
      debugPrint('Araç hatırlatması kurulamadı: $e');
    }
  }

  /// Açılışta: hatırlatmaları yeniden kur; 6 ayı geçmiş araçlar için uygulama içi bildirim düş.
  Future<void> _syncVehicleReminders() async {
    final now = DateTime.now();
    for (final v in _userVehicles) {
      final updated = DateTime.tryParse((v['updated_at'] as String?) ?? '');
      if (updated == null) continue;
      final due = DateTime(updated.year, updated.month + 6, updated.day);
      if (now.isAfter(due)) {
        await UserProfileService.instance.addNotification(
          id: 'vehicle_update_${v['id']}_${due.year}_${due.month}',
          title: 'Araç değerini güncelle',
          message:
              '${v['brand']} ${v['model']} için son güncellemenin üzerinden 6 ay geçti. Varlıklar > Araç & Mülk bölümünden piyasa değerini ve kilometreyi güncelle.',
        );
      } else {
        await _scheduleVehicleReminder(v);
      }
    }
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
          final isCredit = card['type'] == 'CREDIT_CARD';
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
