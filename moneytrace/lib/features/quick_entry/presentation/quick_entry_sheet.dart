import 'package:flutter/material.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/security/security_guard.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../statement_upload/presentation/statement_upload_sheet.dart';

enum EntryType { expense, income, savings }

class QuickEntrySheet extends StatefulWidget {
  final Function(Map<String, dynamic> entryData)? onSave;

  const QuickEntrySheet({
    Key? key,
    this.onSave,
  }) : super(key: key);

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  EntryType _selectedType = EntryType.expense;
  String _selectedAccount = 'Nakit (Elden)';
  String _selectedCategory = 'cat_auto_repair';
  String _selectedCurrency = 'TRY';
  int _selectedVatRate = 10;
  bool _isRecurringSubscription = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  late final List<String> _accounts = [
    'Nakit (Elden)',
    'Cüzdan',
    'Kredi Kartı',
    'Banka / Havale',
    ...RemoteConfigService.instance.paymentMethods
        .where((e) => !e.contains('Nakit'))
  ];

  List<Map<String, dynamic>> get _currentCategories {
    switch (_selectedType) {
      case EntryType.expense:
        return [
          {
            'id': 'cat_market',
            'name': 'Market',
            'icon': Icons.shopping_cart_rounded,
            'color': AppColors.catMarket
          },
          {
            'id': 'cat_dining',
            'name': 'Yeme İçme',
            'icon': Icons.restaurant_rounded,
            'color': AppColors.catDining
          },
          {
            'id': 'cat_transit',
            'name': 'Ulaşım & Yakıt',
            'icon': Icons.directions_car_rounded,
            'color': AppColors.catTransit
          },
          {
            'id': 'cat_utilities',
            'name': 'Fatura',
            'icon': Icons.receipt_long_rounded,
            'color': AppColors.catUtilities
          },
          {
            'id': 'cat_auto_repair',
            'name': 'Oto Tamir & Bakım',
            'icon': Icons.build_circle_rounded,
            'color': const Color(0xFFF59E0B)
          },
          {
            'id': 'cat_subscriptions',
            'name': 'Abonelik',
            'icon': Icons.subscriptions_rounded,
            'color': AppColors.catSubscriptions
          },
          {
            'id': 'cat_health',
            'name': 'Sağlık',
            'icon': Icons.local_pharmacy_rounded,
            'color': AppColors.catHealth
          },
          {
            'id': 'cat_clothing',
            'name': 'Giyim & Alışveriş',
            'icon': Icons.checkroom_rounded,
            'color': const Color(0xFFEC4899)
          },
        ];
      case EntryType.income:
        return [
          {
            'id': 'cat_salary',
            'name': 'Maaş / Bordro',
            'icon': Icons.payments_rounded,
            'color': AppColors.incomeGreen
          },
          {
            'id': 'cat_bonus',
            'name': 'Prim & İkramiye',
            'icon': Icons.card_giftcard_rounded,
            'color': const Color(0xFF10B981)
          },
          {
            'id': 'cat_rent_income',
            'name': 'Kira Geliri',
            'icon': Icons.home_work_rounded,
            'color': const Color(0xFF059669)
          },
          {
            'id': 'cat_dividend',
            'name': 'Faiz & Temettü',
            'icon': Icons.trending_up_rounded,
            'color': const Color(0xFF0D9488)
          },
          {
            'id': 'cat_extra_income',
            'name': 'Ek Gelir',
            'icon': Icons.add_circle_outline_rounded,
            'color': const Color(0xFF14B8A6)
          },
        ];
      case EntryType.savings:
        return [
          {
            'id': 'cat_gold',
            'name': 'Altın / Emtia',
            'icon': Icons.monetization_on_rounded,
            'color': const Color(0xFFF59E0B)
          },
          {
            'id': 'cat_fx',
            'name': 'Döviz (USD/EUR)',
            'icon': Icons.currency_exchange_rounded,
            'color': const Color(0xFF3B82F6)
          },
          {
            'id': 'cat_cash_vault',
            'name': 'Nakit Kasa',
            'icon': Icons.account_balance_wallet_rounded,
            'color': const Color(0xFF10B981)
          },
          {
            'id': 'cat_deposit',
            'name': 'Vadeli Mevduat',
            'icon': Icons.savings_rounded,
            'color': const Color(0xFF6366F1)
          },
          {
            'id': 'cat_stocks',
            'name': 'Hisse & Borsa',
            'icon': Icons.show_chart_rounded,
            'color': const Color(0xFF8B5CF6)
          },
          {
            'id': 'cat_bes',
            'name': 'BES / Emeklilik',
            'icon': Icons.verified_user_rounded,
            'color': const Color(0xFF06B6D4)
          },
          {
            'id': 'cat_crypto',
            'name': 'Kripto Varlık',
            'icon': Icons.currency_bitcoin_rounded,
            'color': const Color(0xFFF97316)
          },
        ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _openReceiptScanner() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StatementUploadSheet(),
    );
  }

  void _submit() {
    // 20 Maddelik Güvenlik Kuralı #10: Rate Limiting
    if (!SecurityGuard.instance
        .checkRateLimit('quick_entry', maxPerMinute: 30)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Lütfen çok hızlı işlem girmeyin (Hız sınırlaması aşıldı).')),
      );
      return;
    }

    final amountCents = CurrencyNormalizer.toMinorUnits(_amountController.text);
    // 20 Maddelik Güvenlik Kuralı #3: Input Validation
    if (amountCents <= 0 ||
        !SecurityGuard.instance.isValidAmountCents(amountCents)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir tutar girin.')),
      );
      return;
    }

    final isCash = _selectedAccount.contains('Nakit') ||
        _selectedAccount.contains('Cüzdan');
    final rawTitle = _titleController.text.trim().isEmpty
        ? 'Hızlı Harcama'
        : _titleController.text.trim();
    final sanitizedTitle = SecurityGuard.instance.sanitizeTextInput(rawTitle);

    final data = {
      'type': _selectedType.name,
      'account': _selectedAccount,
      'payment_method': isCash ? 'CASH' : 'CARD',
      'is_cash': isCash,
      'category_id': _selectedCategory,
      'title': sanitizedTitle,
      'amount_cents': amountCents,
      'currency': _selectedCurrency,
      'date': _selectedDate.toIso8601String().split('T')[0],
      'vat_rate': _selectedVatRate,
      'is_subscription': _isRecurringSubscription,
    };

    widget.onSave?.call(data);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Tutamaç & Kapatma Butonu
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
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'İşlem Ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gider / Gelir / Birikim: tek, alçak, kayan seçici
            _buildModeSelector(),
            const SizedBox(height: 20),

            // Kart / Cüzdan Seçici
            const Text(
              'Kart / Cüzdan',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _accounts.map((acc) {
                  final isSelected = acc == _selectedAccount;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedAccount = acc),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accentBlue
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          acc,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.accentBlue
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Kategori Satırı + Kamera & Mikrofon Aksiyonları
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kategoriler',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_camera_rounded,
                          size: 20, color: AppColors.textSecondary),
                      onPressed: _openReceiptScanner,
                      tooltip: 'Fiş / Belge Tara',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _currentCategories.map((cat) {
                  final isSelected = cat['id'] == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color:
                            isSelected ? Colors.white : cat['color'] as Color,
                      ),
                      label: Text(cat['name'] as String),
                      selected: isSelected,
                      selectedColor: cat['color'] as Color,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected
                              ? cat['color'] as Color
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat['id']);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Başlık
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.edit_note_rounded,
                    color: AppColors.textMuted),
                labelText: 'Başlık (isteğe bağlı)',
                labelStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Tutar & Para Birimi
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.attach_money_rounded,
                          color: AppColors.textMuted),
                      labelText: 'Tutar',
                      hintText: '0,00',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCurrency,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        items: ['TRY', 'USD', 'EUR', 'GBP'].map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              CurrencyNormalizer.formatCents(0, currency: c)
                                      .replaceAll('0,00', '')
                                      .trim() +
                                  ' ' +
                                  c,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _selectedCurrency = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tarih, KDV ve Abonelik Satırı
            Row(
              children: [
                // Tarih
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null)
                        setState(() => _selectedDate = picked);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // KDV Oranı Dropdown
                Expanded(
                  flex: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedVatRate,
                        isExpanded: true,
                        items: [0, 1, 8, 10, 20].map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text('KDV %$v',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _selectedVatRate = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Abonelik Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.repeat_rounded,
                          size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text(
                        'Aylık Düzenli Abonelik',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isRecurringSubscription,
                    activeThumbColor: AppColors.accentBlue,
                    onChanged: (val) =>
                        setState(() => _isRecurringSubscription = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Video 4: Radar Dalgalı Güvenlik ve Harcama Doğrulama Butonu
            RadarCheckoutButton(
              label: 'Harcamayı Doğrula ve Kaydet',
              idleAmountText: _amountController.text.isNotEmpty
                  ? '₺${_amountController.text}'
                  : '₺0,00',
              verifyingAmountText: 'Güvenlik Doğrulanıyor...',
              onPressed: () async {
                await Future.delayed(const Duration(milliseconds: 900));
                _submit();
              },
            ),
          ],
        ),
      ),
    );
  }

  static const _modes = [
    (EntryType.expense, 'Gider', Icons.arrow_outward_rounded, [Color(0xFFE11D48), Color(0xFF9F1239)]),
    (EntryType.income, 'Gelir', Icons.arrow_downward_rounded, [Color(0xFF059669), Color(0xFF064E3B)]),
    (EntryType.savings, 'Birikim', Icons.savings_rounded, [Color(0xFF2563EB), Color(0xFF1E40AF)]),
  ];

  void _selectMode(EntryType type) {
    setState(() {
      _selectedType = type;
      _selectedCategory = _currentCategories.first['id'] as String;
    });
  }

  /// Seçili modun renkli arka planı, seçime göre yatayda kayar (Gider kırmızı, Gelir yeşil, Birikim mavi).
  Widget _buildModeSelector() {
    final index = _modes.indexWhere((m) => m.$1 == _selectedType);
    final selected = _modes[index];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + index.toDouble(), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _modes.length,
              heightFactor: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: selected.$4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: _modes.map((m) {
              final isSelected = m.$1 == _selectedType;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectMode(m.$1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(m.$3, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        m.$2,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
