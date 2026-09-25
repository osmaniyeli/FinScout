import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/services/live_market_service.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/data_changes.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../data/vehicle_catalog.dart';
import '../repositories/assets_repository.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';
import 'widgets/market_news_section.dart';
import 'widgets/credit_card_action_sheet.dart';
import 'widgets/card_payment_flow.dart';
import '../../navigation/tab_add_actions.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> implements TabAddActions {
  final LiveMarketService _marketService = LiveMarketService.instance;
  final TransactionRepository _repository = TransactionRepository();
  int _selectedTab = 0; // 0: Birikim, 1: Araçlar, 2: Kartlar

  bool _isLoadingRates = false;
  Map<String, MarketTicker> _marketTickers = {};

  // Portföy Varlıkları (kullanıcı elle girer)
  double _gramGoldQuantity = 0.0;
  double _gramGoldCostPrice = 0.0; // Alış Maliyeti ₺/gr

  int _ceyrekGoldQuantity = 0;
  double _ceyrekGoldCostPrice = 0.0; // Alış Maliyeti ₺/adet

  double _usdQuantity = 0.0;
  double _usdCostPrice = 0.0; // Alış Kuru ₺/$

  double _eurQuantity = 0.0;
  double _eurCostPrice = 0.0; // Alış Kuru ₺/€

  int _cashTryCents = 0;

  // Araç Varlıkları
  List<Map<String, dynamic>> _userVehicles = [];

  final AssetsRepository _assets = AssetsRepository.instance;
  List<Map<String, dynamic>> _linkedCards = [];
  List<PaymentSource> _paymentSources = const [
    PaymentSource(accountId: null, label: 'Nakit Cüzdan')
  ];

  /// İlk faz: yalnız Yapı Kredi ekstresi okunuyor. Diğer bankalar listede "Yakında" olarak görünür
  /// ama seçilemez; desteklenmeyen bir bankanın kartı "ekstre bekleniyor" durumunda asılı kalmasın.
  static const String _supportedBank = 'Yapı Kredi';
  static const List<String> _comingSoonBanks = [
    'Akbank',
    'Enpara',
    'Garanti BBVA',
    'Halkbank',
    'İş Bankası',
    'QNB',
    'VakıfBank',
    'Ziraat Bankası',
  ];

  @override
  void initState() {
    super.initState();
    _assets.revision.addListener(_onAssetsChanged);
    DataChanges.revision.addListener(_onDataChanged);
    _loadPersistedAssets();
    _fetchMarketRates();
  }

  @override
  void dispose() {
    _assets.revision.removeListener(_onAssetsChanged);
    DataChanges.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  /// Varlık dosyası değişti (kayıt, silme, sıfırlama / hesap silme): ekranı dosyadan yeniden kur.
  void _onAssetsChanged() {
    if (!mounted) return;
    _applyHoldingsFromRepo();
    _loadCardsFromDb();
  }

  /// Ekstre yükleme, manuel kayıt, silme, sıfırlama: kart ve hesap bilgilerini yeniden oku.
  void _onDataChanged() {
    if (!mounted) return;
    _loadCardsFromDb();
  }

  void _applyHoldingsFromRepo() {
    final gram = _assets.holding('gram_altin');
    final ceyrek = _assets.holding('ceyrek_altin');
    final usd = _assets.holding('usd');
    final eur = _assets.holding('eur');
    final cash = _assets.holding('nakit_tl');
    setState(() {
      _gramGoldQuantity = gram['quantity']!;
      _gramGoldCostPrice = gram['cost']!;
      _ceyrekGoldQuantity = ceyrek['quantity']!.toInt();
      _ceyrekGoldCostPrice = ceyrek['cost']!;
      _usdQuantity = usd['quantity']!;
      _usdCostPrice = usd['cost']!;
      _eurQuantity = eur['quantity']!;
      _eurCostPrice = eur['cost']!;
      _cashTryCents = (cash['quantity']! * 100).round();
      _userVehicles = _assets.vehicles;
    });
  }

  /// Elle girilen varlıkları (altın/döviz/nakit, araçlar) cihazdan geri yükler.
  Future<void> _loadPersistedAssets() async {
    await _assets.load();
    if (!mounted) return;
    _applyHoldingsFromRepo();
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
        final minimum = (a['minimum_payment_cents'] as num?)?.toInt();
        final due = _formatIsoDate(a['due_date'] as String?);
        final cut = _formatIsoDate(
            (a['statement_date'] as String?) ?? (a['period_end'] as String?));
        final limitCents = (match?['limit_cents'] as num?)?.toInt();
        final mask = (a['card_mask'] as String?) ?? '';
        final holder = (a['card_holder'] as String?) ?? '';
        cards.add({
          'account_id': a['id'],
          'name': bank,
          'bank': bank,
          'mask': mask.isNotEmpty
              ? mask
              : (isCredit ? 'Kredi Kartı' : 'Vadesiz Hesap'),
          'limit_cents': limitCents,
          'limit': isCredit
              ? (limitCents != null
                  ? CurrencyNormalizer.formatCents(limitCents)
                  : 'Limit girilmedi')
              : 'Vadesiz Hesap',
          'debt_cents': balance,
          'debt':
              balance != null ? CurrencyNormalizer.formatCents(balance) : '—',
          'statement_day': due != null
              ? 'Son ödeme $due'
              : (isCredit ? 'Son ödeme —' : 'Hesap ekstresi'),
          // Ekstrede bankanın yazdığı değerler (tahmin yok)
          'due': due ?? '—',
          'cut': cut ?? '—',
          'minimum_cents': minimum,
          'holder': holder,
          'color': isCredit ? const Color(0xFF7C3AED) : const Color(0xFF10B981),
          'type': isCredit ? 'CREDIT_CARD' : 'CHECKING',
          'manual_id': match?['id'],
        });
      }

      for (final m in manual.where((m) => !used.contains(m['id']))) {
        final limitCents = (m['limit_cents'] as num?)?.toInt() ?? 0;
        cards.add({
          'account_id': null,
          'name': m['bank'],
          'bank': m['bank'],
          'mask': 'Ekstre bekleniyor',
          'limit_cents': limitCents,
          'limit': CurrencyNormalizer.formatCents(limitCents),
          'debt_cents': null,
          'debt': '—',
          'statement_day': 'İlk ekstre yüklenince eşleşir',
          'due': '—',
          'cut': '—',
          'minimum_cents': null,
          'holder': '',
          'color': const Color(0xFF0D9488),
          'type': 'CREDIT_CARD',
          'manual_id': m['id'],
        });
      }

      // Ödeme kaynağı: nakit cüzdan + ekstresi yüklenmiş gerçek vadesiz hesaplar
      final sources = <PaymentSource>[
        const PaymentSource(accountId: null, label: 'Nakit Cüzdan'),
        for (final a in accounts.where((a) => a['account_type'] == 'CHECKING'))
          PaymentSource(
            accountId: a['id'] as String,
            label: [
              '${a['institution_name'] ?? 'Banka'} vadesiz',
              if (((a['card_mask'] as String?) ?? '').isNotEmpty)
                a['card_mask'],
            ].join(' • '),
          ),
      ];

      if (mounted) {
        setState(() {
          _linkedCards = cards;
          _paymentSources = sources;
        });
      }
    } catch (e) {
      debugPrint('Kartları veritabanından yükleme hatası: $e');
    }
  }

  /// Kart ödemesini kayda geçirir (nötr CARDPAYMENT). Hata fırlatılır; ödeme sayfası kullanıcıya gösterir.
  Future<void> _recordCardPayment(Map<String, dynamic> card, int paidCents,
          PaymentSource source, DateTime date) =>
      CardPaymentFlow.record(_repository, card, paidCents, source, date);

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showCardDetail(Map<String, dynamic> card) {
    final isCredit = card['type'] == 'CREDIT_CARD';
    final minimum = (card['minimum_cents'] as num?)?.toInt();
    final holder = (card['holder'] as String?) ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
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
                  Expanded(
                    child: Column(
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
                          holder.isNotEmpty
                              ? '${card['mask']} • $holder'
                              : '${card['mask']}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
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
                  children: isCredit
                      ? [
                          _detailRow('Kart limiti', card['limit'] as String),
                          _detailRow('Dönem borcu', card['debt'] as String,
                              color: AppColors.expenseRed),
                          _detailRow(
                              'Asgari ödeme',
                              minimum != null
                                  ? CurrencyNormalizer.formatCents(minimum)
                                  : '—'),
                          _detailRow(
                              'Hesap kesim tarihi', card['cut'] as String),
                          _detailRow('Son ödeme tarihi', card['due'] as String,
                              color: AppColors.actionPrimary),
                        ]
                      : [
                          _detailRow(
                              'Dönem sonu bakiyesi', card['debt'] as String,
                              color: AppColors.incomeGreen),
                          _detailRow('Ekstre tarihi', card['cut'] as String),
                        ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCredit
                    ? 'Borç, asgari tutar ve tarihler son yüklenen ekstreden okunur. Limiti sen girersin.'
                    : 'Bakiye son yüklenen hesap ekstresinden okunur.',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (isCredit) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      CreditCardActionSheet.show(
                        context,
                        card: card,
                        sourceAccounts: _paymentSources,
                        onPaymentRecorded: (paidCents, source, date) =>
                            _recordCardPayment(card, paidCents, source, date),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 20),
                    label: const Text('Ödemeyi kaydet'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showEditLimitDialog(card);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Limiti düzenle'),
                  ),
                ),
              ],
              if (card['manual_id'] != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await _assets
                            .deleteManualCard(card['manual_id'] as String);
                      } catch (_) {
                        _showError('Kart bilgisi silinemedi.');
                      }
                      await _loadCardsFromDb();
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.expenseRed),
                    label: const Text('Girdiğin limit bilgisini sil',
                        style: TextStyle(
                            color: AppColors.expenseRed,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.expenseRed, content: Text(message)));
  }

  /// Yalnız limit düzenlenir; borç, kesim ve son ödeme ekstreden gelir (salt okunur).
  void _showEditLimitDialog(Map<String, dynamic> card) {
    final current = (card['limit_cents'] as num?)?.toInt() ?? 0;
    final limitController =
        TextEditingController(text: current > 0 ? _centsToInput(current) : '');
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${card['name']} limiti',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: limitController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Kart limiti (₺)',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Ekstreden (değiştirilemez)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                _detailRow('Dönem borcu', card['debt'] as String),
                _detailRow('Hesap kesim tarihi', card['cut'] as String),
                _detailRow('Son ödeme tarihi', card['due'] as String),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                final limitCents =
                    CurrencyNormalizer.toMinorUnits(limitController.text);
                if (limitCents <= 0) {
                  setDialogState(() => error = 'Limit tutarını gir.');
                  return;
                }
                try {
                  await _assets.upsertManualCard({
                    'id': card['manual_id'] ??
                        'mc_${DateTime.now().millisecondsSinceEpoch}',
                    'bank': card['bank'] ?? card['name'],
                    'limit_cents': limitCents,
                  });
                } catch (_) {
                  setDialogState(() => error = 'Limit kaydedilemedi.');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadCardsFromDb();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text(
                        '${card['name']} limiti kaydedildi: ${CurrencyNormalizer.formatCents(limitCents)}.')));
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  /// Kuruşu giriş kutusu biçimine çevirir: 125050 → "1.250,50"
  static String _centsToInput(int cents) {
    final whole = ThousandsInputFormatter.format('${cents ~/ 100}');
    final frac = cents % 100;
    return frac == 0 ? whole : '$whole,${frac.toString().padLeft(2, '0')}';
  }

  void _showAddCardDialog() {
    final limitController = TextEditingController();
    String? selectedBank = _supportedBank;
    String? limitError;

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
                  items: [
                    const DropdownMenuItem(
                        value: _supportedBank, child: Text(_supportedBank)),
                    for (final b in _comingSoonBanks)
                      DropdownMenuItem(
                        value: b,
                        enabled: false,
                        child: Text('$b · Yakında',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                  ],
                  onChanged: (v) => setModalState(() => selectedBank = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                      labelText: 'Kart Limiti (₺)', errorText: limitError),
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
                final bank = selectedBank ?? '';
                final limitCents =
                    CurrencyNormalizer.toMinorUnits(limitController.text);
                if (bank.isEmpty || limitCents <= 0) {
                  setModalState(() => limitError = 'Kart limitini gir.');
                  return;
                }
                try {
                  await _assets.upsertManualCard({
                    'id': 'mc_${DateTime.now().millisecondsSinceEpoch}',
                    'bank': bank,
                    'limit_cents': limitCents,
                  });
                } catch (_) {
                  setModalState(
                      () => limitError = 'Kart kaydedilemedi, tekrar dene.');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
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

  /// Birikim türleri: anahtar (AssetsRepository), başlık, birim, piyasa sembolü (LiveMarketService).
  static const List<
      ({
        String key,
        String title,
        String unit,
        String? symbol,
        IconData icon,
        Color color
      })> _holdingTypes = [
    (
      key: 'gram_altin',
      title: 'Gram Altın',
      unit: 'gr',
      symbol: 'ALTIN_GR',
      icon: Icons.monetization_on_rounded,
      color: Color(0xFFF59E0B)
    ),
    (
      key: 'ceyrek_altin',
      title: 'Çeyrek Altın',
      unit: 'adet',
      symbol: 'CEYREK',
      icon: Icons.circle_rounded,
      color: Color(0xFFEAB308)
    ),
    (
      key: 'usd',
      title: 'Amerikan Doları (USD)',
      unit: 'USD',
      symbol: 'USD',
      icon: Icons.attach_money_rounded,
      color: Color(0xFF10B981)
    ),
    (
      key: 'eur',
      title: 'Euro (EUR)',
      unit: 'EUR',
      symbol: 'EUR',
      icon: Icons.euro_rounded,
      color: Color(0xFF2563EB)
    ),
    (
      key: 'nakit_tl',
      title: 'TL Nakit',
      unit: '₺',
      symbol: null,
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.incomeGreen
    ),
  ];

  /// "Varlık ekle": tür seç → miktar (+ isteğe bağlı alış fiyatı) → kaydet.
  void _showAddSavingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
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
                'Varlık ekle',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Türü seç; miktarı ve istersen alış fiyatını gir. Eldeki miktarın üstüne eklenir.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              for (final t in _holdingTypes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(t.icon, color: t.color),
                  title: Text(t.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddHoldingDialog(t.key);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Seçilen türe miktar ekler. Alış fiyatı verilirse ve eldeki miktarın maliyeti biliniyorsa
  /// ağırlıklı ortalama maliyet tutulur; biri bilinmiyorsa maliyet "bilinmiyor" (0) olur, K/Z uydurulmaz.
  void _showAddHoldingDialog(String key) {
    final type = _holdingTypes.firstWhere((t) => t.key == key);
    final isCash = key == 'nakit_tl';
    final current = _assets.holding(key);
    final oldQty = current['quantity']!;
    final oldCost = current['cost']!;
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    String? qtyError;
    String? saveError;
    bool saving = false;

    final qtyLabel = isCash
        ? 'Eklenecek tutar (₺)'
        : key == 'ceyrek_altin'
            ? 'Adet'
            : key == 'gram_altin'
                ? 'Gram miktarı (gr)'
                : 'Miktar (${type.unit})';
    final costLabel = key == 'gram_altin'
        ? 'Alış fiyatı (₺/gr, isteğe bağlı)'
        : key == 'ceyrek_altin'
            ? 'Alış fiyatı (₺/adet, isteğe bağlı)'
            : 'Alış kuru (₺, isteğe bağlı)';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${type.title} ekle',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (oldQty > 0) ...[
                  Text(
                    isCash
                        ? 'Şu an: ${CurrencyNormalizer.formatCents((oldQty * 100).round())}'
                        : 'Şu an: ${_centsToInput((oldQty * 100).round())} ${type.unit}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: qtyController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration:
                      InputDecoration(labelText: qtyLabel, errorText: qtyError),
                  onChanged: (_) {
                    if (qtyError != null) {
                      setDialogState(() => qtyError = null);
                    }
                  },
                ),
                if (!isCash) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: costController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: InputDecoration(labelText: costLabel),
                  ),
                ],
                if (saveError != null) ...[
                  const SizedBox(height: 10),
                  Text(saveError!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.expenseRed)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      // Türkçe sayı biçimi: "10.000" on bin, "1.250,50" bin iki yüz elli virgül elli
                      final addQty =
                          CurrencyNormalizer.toMinorUnits(qtyController.text) /
                              100.0;
                      if (addQty <= 0) {
                        setDialogState(() => qtyError =
                            isCash ? 'Eklenecek tutarı gir.' : 'Miktarı gir.');
                        return;
                      }
                      if (key == 'ceyrek_altin' &&
                          addQty != addQty.roundToDouble()) {
                        setDialogState(() =>
                            qtyError = 'Çeyrek altın adedi tam sayı olmalı.');
                        return;
                      }
                      final addCost = isCash
                          ? 0.0
                          : CurrencyNormalizer.toMinorUnits(
                                  costController.text) /
                              100.0;
                      final newQty = oldQty + addQty;
                      final double newCost;
                      if (isCash) {
                        newCost = 0;
                      } else if (oldQty <= 0) {
                        newCost = addCost;
                      } else if (oldCost > 0 && addCost > 0) {
                        newCost =
                            (oldQty * oldCost + addQty * addCost) / newQty;
                      } else {
                        newCost = 0;
                      }
                      setDialogState(() {
                        saving = true;
                        saveError = null;
                      });
                      try {
                        // Ekran, AssetsRepository.revision üzerinden kendini yeniler.
                        await _assets.setHolding(key,
                            quantity: newQty,
                            cost: newCost,
                            target: current['target']!);
                      } catch (_) {
                        setDialogState(() {
                          saving = false;
                          saveError = 'Kaydedilemedi, tekrar dene.';
                        });
                        return;
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      setState(() => _selectedTab = 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.incomeGreen,
                          content: Text('${type.title} eklendi.'),
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

  /// + menüsü (Varlıklar): ilgili bölmeye geçip o ekleme akışını açar.
  @override
  List<TabAddAction> get addActions => [
        TabAddAction(
          icon: Icons.savings_rounded,
          title: 'Altın / döviz / nakit',
          subtitle: 'Gram, çeyrek altın, USD, EUR, TL nakit',
          onSelected: () {
            setState(() => _selectedTab = 0);
            _showAddSavingsSheet();
          },
        ),
        TabAddAction(
          icon: Icons.directions_car_rounded,
          title: 'Araç',
          subtitle: 'Marka, model ve güncel piyasa değeri',
          onSelected: () {
            setState(() => _selectedTab = 1);
            _showVehicleDialog();
          },
        ),
        TabAddAction(
          icon: Icons.credit_card_rounded,
          title: 'Kart (limit)',
          subtitle: 'Kredi kartı limitini gir; ekstre gelince eşleşir',
          onSelected: () {
            setState(() => _selectedTab = 2);
            _showAddCardDialog();
          },
        ),
      ];

  void _showEditAssetDialog(String key) {
    String title = '';
    String qtyLabel = 'Miktar';
    String costLabel = 'Alış Birim Maliyeti (₺)';
    bool showCost = true;

    final qtyController = TextEditingController();
    final costController = TextEditingController();

    // Kayıtlı değeri Türkçe biçimle doldurur: 1250.5 → "1.250,50"
    String input(double v) => v > 0 ? _centsToInput((v * 100).round()) : '';

    if (key == 'gram_altin') {
      title = 'Gram Altın';
      qtyLabel = 'Gram miktarı (gr)';
      costLabel = 'Alış fiyatı (₺/gr, isteğe bağlı)';
      qtyController.text = input(_gramGoldQuantity);
      costController.text = input(_gramGoldCostPrice);
    } else if (key == 'ceyrek_altin') {
      title = 'Çeyrek Altın';
      qtyLabel = 'Adet';
      costLabel = 'Alış fiyatı (₺/adet, isteğe bağlı)';
      qtyController.text = input(_ceyrekGoldQuantity.toDouble());
      costController.text = input(_ceyrekGoldCostPrice);
    } else if (key == 'usd') {
      title = 'Amerikan Doları';
      qtyLabel = 'Miktar (USD)';
      costLabel = 'Alış kuru (₺, isteğe bağlı)';
      qtyController.text = input(_usdQuantity);
      costController.text = input(_usdCostPrice);
    } else if (key == 'eur') {
      title = 'Euro';
      qtyLabel = 'Miktar (EUR)';
      costLabel = 'Alış kuru (₺, isteğe bağlı)';
      qtyController.text = input(_eurQuantity);
      costController.text = input(_eurCostPrice);
    } else {
      title = 'TL Nakit';
      qtyLabel = 'Nakit bakiye (₺)';
      showCost = false;
      qtyController.text =
          _cashTryCents > 0 ? _centsToInput(_cashTryCents) : '';
    }

    String? error;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration:
                      InputDecoration(labelText: qtyLabel, errorText: error),
                ),
                if (showCost) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: costController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [ThousandsInputFormatter()],
                    decoration: InputDecoration(labelText: costLabel),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Miktarı 0 yaparsan bu varlık listeden kalkar.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                // Türkçe sayı biçimi: "10.000" on bin, "1.250,50" bin iki yüz elli virgül elli
                double num(TextEditingController c) =>
                    CurrencyNormalizer.toMinorUnits(c.text) / 100.0;
                final qty = num(qtyController);
                final cost = showCost ? num(costController) : 0.0;
                try {
                  // Ekran, AssetsRepository.revision üzerinden kendini yeniler.
                  await _assets.setHolding(key, quantity: qty, cost: cost);
                } catch (_) {
                  setDialogState(() => error = 'Kaydedilemedi, tekrar dene.');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.incomeGreen,
                    content: Text('$title kaydedildi.'),
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

  /// Aşağı çekince: kurlar + kart/hesap bilgileri.
  Future<void> _refreshAll() async {
    await Future.wait([_fetchMarketRates(), _loadCardsFromDb()]);
  }

  /// Varlığı değerlemek için kullanılan fiyat: piyasanın alış fiyatı (bozdurursan eline geçen).
  /// Alış fiyatı yoksa satış fiyatı; hiç kur yoksa 0 (ekranda "—").
  double _valuationPrice(String symbol) {
    final t = _marketTickers[symbol];
    if (t == null) return 0.0;
    return t.buyingPrice > 0 ? t.buyingPrice : t.sellingPrice;
  }

  String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Değerleme: piyasanın alış fiyatı (kur yoksa 0 → "—")
    final gramGoldPrice = _valuationPrice('ALTIN_GR');
    final ceyrekGoldPrice = _valuationPrice('CEYREK');
    final usdPrice = _valuationPrice('USD');
    final eurPrice = _valuationPrice('EUR');

    final int gramGoldTotalCents =
        (gramGoldPrice * _gramGoldQuantity * 100).round();
    final int ceyrekGoldTotalCents =
        (ceyrekGoldPrice * _ceyrekGoldQuantity * 100).round();
    final int usdTotalCents = (usdPrice * _usdQuantity * 100).round();
    final int eurTotalCents = (eurPrice * _eurQuantity * 100).round();

    final int vehicleTotalCents = _userVehicles.fold(
        0, (sum, v) => sum + ((v['value_cents'] as num?)?.toInt() ?? 0));
    final int savingsTotalCents = gramGoldTotalCents +
        ceyrekGoldTotalCents +
        usdTotalCents +
        eurTotalCents +
        _cashTryCents;
    final int totalWealthCents = savingsTotalCents + vehicleTotalCents;

    // Miktarı girilmiş ama kuru alınamamış varlık varsa toplamda eksik kalır; kullanıcıya söylenir.
    final bool missingRate = (_gramGoldQuantity > 0 && gramGoldPrice <= 0) ||
        (_ceyrekGoldQuantity > 0 && ceyrekGoldPrice <= 0) ||
        (_usdQuantity > 0 && usdPrice <= 0) ||
        (_eurQuantity > 0 && eurPrice <= 0);

    // Kâr / Zarar hesapları (yalnız alış maliyeti girildiyse ve kur varsa)
    final int gramGoldProfitCents = gramGoldTotalCents -
        (_gramGoldCostPrice * _gramGoldQuantity * 100).round();
    final int ceyrekGoldProfitCents = ceyrekGoldTotalCents -
        (_ceyrekGoldCostPrice * _ceyrekGoldQuantity * 100).round();
    final int usdProfitCents =
        usdTotalCents - (_usdCostPrice * _usdQuantity * 100).round();
    final int eurProfitCents =
        eurTotalCents - (_eurCostPrice * _eurQuantity * 100).round();

    String qtyText(double v) => _centsToInput((v * 100).round());
    String priceText(double p) =>
        p > 0 ? CurrencyNormalizer.formatCents((p * 100).round()) : '—';
    String? profitText(double cost, double price, double qty, int profit) =>
        cost > 0 && price > 0 && qty > 0
            ? '${profit >= 0 ? "+" : ""}${CurrencyNormalizer.formatCents(profit)}'
            : null;

    final List<Map<String, dynamic>> allAssets = [
      {
        'key': 'gram_altin',
        'title': 'Gram Altın',
        'amount': '${qtyText(_gramGoldQuantity)} gr',
        'cost': _gramGoldCostPrice > 0
            ? 'Maliyet: ${priceText(_gramGoldCostPrice)}/gr'
            : 'Alış kuru: ${priceText(gramGoldPrice)}/gr',
        'current_value': gramGoldPrice > 0 || _gramGoldQuantity == 0
            ? CurrencyNormalizer.formatCents(gramGoldTotalCents)
            : '—',
        'profit_text': profitText(_gramGoldCostPrice, gramGoldPrice,
            _gramGoldQuantity, gramGoldProfitCents),
        'is_profit': gramGoldProfitCents >= 0,
        'icon': Icons.monetization_on_rounded,
        'color': const Color(0xFFF59E0B),
        'qty': _gramGoldQuantity,
      },
      {
        'key': 'ceyrek_altin',
        'title': 'Çeyrek Altın',
        'amount': '$_ceyrekGoldQuantity adet',
        'cost': _ceyrekGoldCostPrice > 0
            ? 'Maliyet: ${priceText(_ceyrekGoldCostPrice)}/adet'
            : 'Alış kuru: ${priceText(ceyrekGoldPrice)}/adet',
        'current_value': ceyrekGoldPrice > 0 || _ceyrekGoldQuantity == 0
            ? CurrencyNormalizer.formatCents(ceyrekGoldTotalCents)
            : '—',
        'profit_text': profitText(_ceyrekGoldCostPrice, ceyrekGoldPrice,
            _ceyrekGoldQuantity.toDouble(), ceyrekGoldProfitCents),
        'is_profit': ceyrekGoldProfitCents >= 0,
        'icon': Icons.circle_rounded,
        'color': const Color(0xFFEAB308),
        'qty': _ceyrekGoldQuantity.toDouble(),
      },
      {
        'key': 'usd',
        'title': 'Amerikan Doları (USD)',
        'amount': '${qtyText(_usdQuantity)} USD',
        'cost': _usdCostPrice > 0
            ? 'Maliyet: ${priceText(_usdCostPrice)}'
            : 'Alış kuru: ${priceText(usdPrice)}',
        'current_value': usdPrice > 0 || _usdQuantity == 0
            ? CurrencyNormalizer.formatCents(usdTotalCents)
            : '—',
        'profit_text':
            profitText(_usdCostPrice, usdPrice, _usdQuantity, usdProfitCents),
        'is_profit': usdProfitCents >= 0,
        'icon': Icons.attach_money_rounded,
        'color': const Color(0xFF10B981),
        'qty': _usdQuantity,
      },
      {
        'key': 'eur',
        'title': 'Euro (EUR)',
        'amount': '${qtyText(_eurQuantity)} EUR',
        'cost': _eurCostPrice > 0
            ? 'Maliyet: ${priceText(_eurCostPrice)}'
            : 'Alış kuru: ${priceText(eurPrice)}',
        'current_value': eurPrice > 0 || _eurQuantity == 0
            ? CurrencyNormalizer.formatCents(eurTotalCents)
            : '—',
        'profit_text':
            profitText(_eurCostPrice, eurPrice, _eurQuantity, eurProfitCents),
        'is_profit': eurProfitCents >= 0,
        'icon': Icons.euro_rounded,
        'color': const Color(0xFF2563EB),
        'qty': _eurQuantity,
      },
      {
        'key': 'nakit_tl',
        'title': 'TL Nakit',
        'amount': 'Nakit',
        'cost': 'Elle girilen bakiye',
        'current_value': CurrencyNormalizer.formatCents(_cashTryCents),
        'profit_text': null,
        'is_profit': true,
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.incomeGreen,
        'qty': _cashTryCents / 100.0,
      },
    ];
    // Yalnız eldeki varlıklar listelenir; yenisi "Varlık ekle" ile eklenir.
    final assets =
        allAssets.where((a) => (a['qty'] as double) > 0).toList();

    // Kurun kaynağı ve kaynaktaki güncellenme zamanı
    final rateTimes = _marketTickers.values.map((t) => t.lastUpdated).toList()
      ..sort();
    final DateTime? ratesUpdatedAt = rateTimes.isEmpty ? null : rateTimes.last;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Varlıklarım',
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
            onPressed: _isLoadingRates ? null : _refreshAll,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: AppColors.actionPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segment Kontrolcü: [Birikim] | [Araçlar] | [Kartlar]
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: [
                    _buildTabItem('Birikim', 0),
                    _buildTabItem('Araçlar', 1),
                    _buildTabItem('Kartlar', 2),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedTab == 0) ...[
                // Toplam Portföy Değeri
                FinanceCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOPLAM VARLIK DEĞERİ',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5),
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
                      const SizedBox(height: 10),
                      _detailRow('Birikim (altın, döviz, nakit)',
                          CurrencyNormalizer.formatCents(savingsTotalCents)),
                      if (vehicleTotalCents > 0)
                        _detailRow('Araçlar (girdiğin değer)',
                            CurrencyNormalizer.formatCents(vehicleTotalCents)),
                      if (missingRate) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Kur alınamadı; kuru olmayan varlıklar toplama eklenmedi.',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.expenseRed),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Kur ve emtia bandı (serbest piyasa, satış fiyatı)
                const Text(
                  'PİYASA KURLARI (SATIŞ)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTickerChip('USD/TRY', _marketTickers['USD']),
                      _buildTickerChip('EUR/TRY', _marketTickers['EUR']),
                      _buildTickerChip(
                          'Gram Altın', _marketTickers['ALTIN_GR']),
                      _buildTickerChip(
                          'Çeyrek Altın', _marketTickers['CEYREK']),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ratesUpdatedAt != null
                      ? 'Kaynak: Truncgil Finans (serbest piyasa) • Güncelleme: ${_formatDateTime(ratesUpdatedAt)}'
                      : 'Kaynak: Truncgil Finans (serbest piyasa) • Kur alınamadı',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted, height: 1.4),
                ),
                const Text(
                  'Varlık değeri piyasanın alış fiyatıyla hesaplanır. Bilgi amaçlıdır, yatırım tavsiyesi değildir.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Varlıklar Listesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Birikimlerim',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    TextButton.icon(
                      onPressed: _showAddSavingsSheet,
                      icon: const Icon(Icons.add_rounded,
                          size: 16, color: AppColors.actionPrimary),
                      label: const Text('Varlık ekle',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.actionPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (assets.isEmpty)
                  FinanceCard(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.savings_outlined,
                              size: 36, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          const Text('Henüz birikim eklenmedi',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          const Text(
                              'Altın, döviz ya da nakit ekle; güncel kurla değeri hesaplanır.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _showAddSavingsSheet,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Varlık ekle'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
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
              ] else if (_selectedTab == 1) ...[
                _buildVehiclesView(),
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

  Widget _buildVehiclesView() {
    final int vehicleTotalCents = _userVehicles.fold(
        0, (sum, v) => sum + ((v['value_cents'] as num?)?.toInt() ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      'Aracını ve güncel piyasa değerini girersen değer, toplam varlıkta ayrı satır olarak görünür.',
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
            if (fuel == 'Elektrik') {
              badgeColor = const Color(0xFF00D084);
            } else if (fuel == 'Dizel') {
              badgeColor = const Color(0xFF475569);
            } else if (fuel == 'Benzin') {
              badgeColor = const Color(0xFFF97316);
            } else if (fuel == 'Hibrit') {
              badgeColor = const Color(0xFF06B6D4);
            }

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
          }),
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
    // Eksik alan / kayıt hatası diyaloğun içinde gösterilir (SnackBar diyaloğun arkasında kalırdı).
    String? formError;

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
                if (formError != null) ...[
                  Text(formError!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expenseRed)),
                  const SizedBox(height: 6),
                ],
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
                  try {
                    await _assets.deleteVehicle(id);
                  } catch (_) {
                    _showError('Araç silinemedi, tekrar dene.');
                    return;
                  }
                  await NotificationService.instance
                      .cancel(NotificationService.stableId('vehicle|$id'));
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
                final missing = [
                  if (brandName.isEmpty) 'marka',
                  if (modelName.isEmpty) 'model',
                  if (selectedFuel == null) 'yakıt tipi',
                  if (valueCents <= 0) 'piyasa değeri',
                ];
                if (missing.isNotEmpty) {
                  setModalState(() =>
                      formError = 'Eksik: ${missing.join(', ')}.');
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
                try {
                  await _assets.upsertVehicle(vehicle);
                } catch (_) {
                  setModalState(
                      () => formError = 'Araç kaydedilemedi, tekrar dene.');
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await NotificationService.instance.requestPermission();
                await _scheduleVehicleReminder(vehicle);
                if (!mounted) return;
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
              '${v['brand']} ${v['model']} için son güncellemenin üzerinden 6 ay geçti. Varlıklar › Araçlar bölümünden piyasa değerini ve kilometreyi güncelle.',
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
                    const Text('Veriler yalnız bu telefonda',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
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
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                                [
                                  card['mask'],
                                  if (((card['holder'] as String?) ?? '')
                                      .isNotEmpty)
                                    card['holder'],
                                  card['statement_day'],
                                ].join(' • '),
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
        }),
      ],
    );
  }

  /// Kur kutucuğu. Değişim yüzdesi kaynaktan (Truncgil "Change") gelir; kur yoksa gösterilmez.
  Widget _buildTickerChip(String title, MarketTicker? ticker) {
    final changeRate = ticker?.changeRate;
    final isPositive = (changeRate ?? 0) >= 0;
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
              Text(ticker?.formattedPrice ?? '—',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
            ],
          ),
          if (changeRate != null) ...[
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
                '${isPositive ? "+" : ""}%${changeRate.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isPositive
                        ? const Color(0xFF166534)
                        : const Color(0xFF991B1B)),
              ),
            ),
          ],
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
}
