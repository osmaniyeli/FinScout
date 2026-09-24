import 'package:flutter/material.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../../../core/security/security_guard.dart';

enum EntryType { expense, income }

/// Manuel işlem girişi: tür, kategori, başlık, TL tutar ve tarih.
/// Kayıt doğrudan yerel veritabanına yazılır (saveManualTransaction DataChanges.notify çağırır).
/// Manuel giriş her pakette sınırsızdır; yalnız dakikada 30 kayıt koruması vardır.
class QuickEntrySheet extends StatefulWidget {
  /// Kayıt başarıyla yazıldıktan sonra çağrılır.
  final VoidCallback? onSaved;
  final TransactionRepository? repository;

  const QuickEntrySheet({
    Key? key,
    this.onSaved,
    this.repository,
  }) : super(key: key);

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  EntryType _selectedType = EntryType.expense;
  String _selectedCategory = 'cat_market';
  bool _isSaving = false;
  String? _titleError;
  String? _amountError;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  late final TransactionRepository _repository =
      widget.repository ?? TransactionRepository();

  // Kimlikler categories tablosundaki kayıtlarla aynı (v1/v2/v3 tohum SQL'leri).
  static const _expenseCategories = [
    ('cat_market', 'Market', Icons.shopping_cart_rounded, AppColors.catMarket),
    ('cat_dining', 'Yeme İçme', Icons.restaurant_rounded, AppColors.catDining),
    ('cat_transit', 'Ulaşım', Icons.directions_car_rounded, AppColors.catTransit),
    ('cat_fuel', 'Akaryakıt', Icons.local_gas_station_rounded, Color(0xFFE65100)),
    ('cat_utilities', 'Fatura', Icons.receipt_long_rounded, AppColors.catUtilities),
    ('cat_subscriptions', 'Abonelik', Icons.subscriptions_rounded, AppColors.catSubscriptions),
    ('cat_health', 'Sağlık', Icons.local_pharmacy_rounded, AppColors.catHealth),
    ('cat_clothing', 'Giyim & Alışveriş', Icons.checkroom_rounded, Color(0xFFEC4899)),
    ('cat_auto_repair', 'Oto Tamir & Bakım', Icons.build_circle_rounded, Color(0xFFF59E0B)),
    ('cat_general', 'Diğer', Icons.more_horiz_rounded, Color(0xFF616161)),
  ];

  static const _incomeCategories = [
    ('cat_salary', 'Maaş / Bordro', Icons.payments_rounded, AppColors.incomeGreen),
    ('cat_bonus', 'Prim & İkramiye', Icons.card_giftcard_rounded, Color(0xFF10B981)),
    ('cat_rent_income', 'Kira Geliri', Icons.home_work_rounded, Color(0xFF059669)),
    ('cat_dividend', 'Faiz & Temettü', Icons.trending_up_rounded, Color(0xFF0D9488)),
    ('cat_extra_income', 'Ek Gelir', Icons.add_circle_outline_rounded, Color(0xFF14B8A6)),
  ];

  List<(String, String, IconData, Color)> get _currentCategories =>
      _selectedType == EntryType.expense ? _expenseCategories : _incomeCategories;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final rawTitle = _titleController.text.trim();
    final amountCents = CurrencyNormalizer.toMinorUnits(_amountController.text);
    final titleError = rawTitle.isEmpty ? 'Başlık girin (ör. Market alışverişi).' : null;
    final amountError = _amountController.text.trim().isEmpty
        ? 'Tutar girin.'
        : (amountCents <= 0 || !SecurityGuard.instance.isValidAmountCents(amountCents))
            ? 'Tutar 0\'dan büyük ve geçerli olmalı.'
            : null;
    setState(() {
      _titleError = titleError;
      _amountError = amountError;
    });
    if (titleError != null || amountError != null) return;

    // Güvenlik: dakikada en fazla 30 manuel kayıt
    if (!SecurityGuard.instance.checkRateLimit('quick_entry', maxPerMinute: 30)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Çok hızlı kayıt yapıldı. Bir dakika sonra tekrar deneyin.')),
      );
      return;
    }

    final title = SecurityGuard.instance.sanitizeTextInput(rawTitle);
    final isExpense = _selectedType == EntryType.expense;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await _repository.saveManualTransaction(
        txKind: isExpense ? 'PURCHASE' : 'OTHER',
        title: title,
        amountCents: amountCents,
        isExpense: isExpense,
        categoryId: _selectedCategory,
        date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
            backgroundColor: AppColors.expenseRed,
            content: Text('İşlem kaydedilemedi: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved?.call();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.dynamicIncome,
        content: Text('İşlem kaydedildi: $title'),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? error,
    String? suffix,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      labelText: label,
      hintText: hint,
      errorText: error,
      suffixText: suffix,
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
    );
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
            // Üst Tutamaç
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
                const Text(
                  'İşlem Ekle',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textSecondary),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tür: Gider / Gelir
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<EntryType>(
                segments: const [
                  ButtonSegment(
                      value: EntryType.expense,
                      label: Text('Gider'),
                      icon: Icon(Icons.arrow_outward_rounded)),
                  ButtonSegment(
                      value: EntryType.income,
                      label: Text('Gelir'),
                      icon: Icon(Icons.arrow_downward_rounded)),
                ],
                selected: {_selectedType},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _selectedType = s.first;
                  _selectedCategory = _currentCategories.first.$1;
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Kategori
            const Text(
              'Kategori',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentCategories.map((cat) {
                final (id, name, icon, color) = cat;
                final isSelected = id == _selectedCategory;
                return ChoiceChip(
                  avatar: Icon(icon,
                      size: 16, color: isSelected ? Colors.white : color),
                  label: Text(name),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: color,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: isSelected ? color : const Color(0xFFE2E8F0)),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Başlık
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              decoration: _fieldDecoration(
                label: 'Başlık',
                icon: Icons.edit_note_rounded,
                hint: 'ör. Market alışverişi',
                error: _titleError,
              ).copyWith(counterText: ''),
            ),
            const SizedBox(height: 14),

            // Tutar (yalnız TL)
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: const [ThousandsInputFormatter()],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: _fieldDecoration(
                label: 'Tutar',
                icon: Icons.currency_lira_rounded,
                hint: '0',
                error: _amountError,
                suffix: '₺',
              ),
            ),
            const SizedBox(height: 14),

            // Tarih
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 1, 12, 31),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    const Text('Tarih',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Kaydet',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
