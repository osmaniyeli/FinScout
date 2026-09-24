// lib/features/goals/presentation/add_goal_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../models/financial_goal.dart';

/// Hedef ekleme / düzenleme formu.
/// [initialGoal] verilirse düzenleme modunda açılır (biriken tutar burada değişmez; katkılarla değişir).
/// [onSave] kaydı yapar; başarılı olursa sayfa `true` ile kapanır, hata olursa açık kalır.
class AddGoalSheet extends StatefulWidget {
  final FinancialGoal? initialGoal;
  final Future<void> Function(FinancialGoal goal) onSave;

  const AddGoalSheet({
    Key? key,
    this.initialGoal,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _initialSavedController = TextEditingController();

  GoalCategory _selectedCategory = GoalCategory.other;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 365));
  bool _saving = false;

  bool get _isEdit => widget.initialGoal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.initialGoal;
    if (g != null) {
      _titleController.text = g.title;
      _selectedCategory = g.category;
      _selectedDate = g.targetDate;
      _targetAmountController.text = _centsToInput(g.targetAmountCents);
    }
  }

  /// Kuruş değerini giriş alanı biçimine çevirir: 125000050 -> "1.250.000,50"
  static String _centsToInput(int cents) {
    final whole = ThousandsInputFormatter.format((cents ~/ 100).toString());
    final frac = cents % 100;
    return frac == 0 ? whole : '$whole,${frac.toString().padLeft(2, '0')}';
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    _initialSavedController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showError('Lütfen hedef adı girin.');
      return;
    }

    final targetCents =
        CurrencyNormalizer.toMinorUnits(_targetAmountController.text);
    if (targetCents <= 0) {
      _showError('Lütfen geçerli bir hedef tutar girin.');
      return;
    }

    final FinancialGoal goal;
    final existing = widget.initialGoal;
    if (existing != null) {
      goal = existing.copyWith(
        title: title,
        category: _selectedCategory,
        targetAmountCents: targetCents,
        targetDate: _selectedDate,
      );
    } else {
      final initialCents = _initialSavedController.text.trim().isEmpty
          ? 0
          : CurrencyNormalizer.toMinorUnits(_initialSavedController.text);
      goal = FinancialGoal(
        id: 'goal_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        category: _selectedCategory,
        targetAmountCents: targetCents,
        currentSavedCents: initialCents > 0 ? initialCents : 0,
        targetDate: _selectedDate,
        createdAt: DateTime.now(),
      );
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(goal);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError('Hedef kaydedilemedi. Lütfen tekrar deneyin.');
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Düzenlenen hedefin tarihi geçmişte olabilir; seçici aralığı onu da kapsamalı.
    final first = _selectedDate.isBefore(today) ? _selectedDate : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365 * 30)),
      helpText: 'Hedef tarihi',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  InputDecoration _decoration(String label, {String? hint, String? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      labelStyle: const TextStyle(fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _selectedCategory.themeColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sürükleme Tutamacı
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Başlık
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedCategory.iconData,
                      color: themeColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isEdit ? 'Hedefi Düzenle' : 'Yeni Birikim Hedefi',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
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
            const SizedBox(height: 14),

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
              children: GoalCategory.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  avatar: Icon(
                    cat.iconData,
                    size: 16,
                    color: isSelected ? Colors.white : cat.themeColor,
                  ),
                  label: Text(cat.displayName),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: cat.themeColor,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color:
                          isSelected ? cat.themeColor : AppColors.borderLight,
                    ),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Hedef Adı
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _decoration('Hedef adı', hint: 'Örn. Araba peşinatı'),
            ),
            const SizedBox(height: 12),

            // Hedef Tutar & (yalnız yeni hedefte) Mevcut Birikim
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [ThousandsInputFormatter()],
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                    decoration: _decoration('Hedef tutar',
                        hint: '100.000', prefix: '₺ '),
                  ),
                ),
                if (!_isEdit) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _initialSavedController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [ThousandsInputFormatter()],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                      decoration:
                          _decoration('Şu an biriken', hint: '0', prefix: '₺ '),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Hedef Tarih Seçici
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hedef tarihi: ${_formatDate(_selectedDate)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.edit,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEdit ? 'Değişiklikleri Kaydet' : 'Hedefi Kaydet',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
