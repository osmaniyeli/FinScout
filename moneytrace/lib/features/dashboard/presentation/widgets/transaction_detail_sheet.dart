// lib/features/dashboard/presentation/widgets/transaction_detail_sheet.dart

import 'package:flutter/material.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/theme/app_colors.dart';

enum _CategoryScope { thisOnly, allFromMerchant }

class TransactionDetailSheet extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onDelete;
  final TransactionRepository? repository;

  const TransactionDetailSheet({
    Key? key,
    required this.transaction,
    this.onDelete,
    this.repository,
  }) : super(key: key);

  static void show(BuildContext context,
      {required Map<String, dynamic> transaction,
      VoidCallback? onDelete,
      TransactionRepository? repository}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionDetailSheet(
        transaction: transaction,
        onDelete: onDelete,
        repository: repository,
      ),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  // Gelir tarafında kullanılan kategoriler (categories tablosunda gelir/gider ayrımı kolonu yok).
  static const _incomeCategoryIds = {
    'cat_salary',
    'cat_bonus',
    'cat_rent_income',
    'cat_dividend',
    'cat_extra_income',
  };

  late final TransactionRepository _repository =
      widget.repository ?? TransactionRepository();
  String? _categoryId;
  String? _categoryName;
  bool _isUpdating = false;

  Map<String, dynamic> get transaction => widget.transaction;
  VoidCallback? get onDelete => widget.onDelete;

  @override
  void initState() {
    super.initState();
    _categoryId = transaction['category_id'] as String?;
    _categoryName = transaction['category_name'] as String?;
  }

  String get _merchant =>
      ((transaction['counterparty'] as String?) ?? '').trim();

  Color _parseColor(Object? hex) {
    final raw = (hex as String?)?.replaceAll('#', '') ?? '';
    final value = int.tryParse('FF$raw', radix: 16);
    return value == null ? AppColors.textMuted : Color(value);
  }

  Future<void> _changeCategory() async {
    final txId = transaction['id'] as String?;
    if (txId == null || _isUpdating) return;

    final List<Map<String, dynamic>> categories;
    try {
      categories = await _repository.getCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kategoriler yüklenemedi: $e')));
      return;
    }
    if (!mounted) return;

    final picked = await _pickCategory(categories);
    if (picked == null || picked['id'] == _categoryId || !mounted) return;

    final pickedName = picked['name'] as String;
    final merchant = _merchant;
    final canApplyToAll = merchant.length >= 3;
    final scope = await showDialog<_CategoryScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kategori: $pickedName'),
        content: Text(canApplyToAll
            ? 'Yalnız bu işlem mi değişsin, yoksa "$merchant" satıcısının tüm işlemleri mi? '
                'Tümü seçilirse sonraki ekstrelerde de bu kategori kullanılır.'
            : 'Bu işlemin kategorisi değişecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç')),
          if (canApplyToAll)
            OutlinedButton(
                onPressed: () =>
                    Navigator.pop(ctx, _CategoryScope.allFromMerchant),
                child: const Text('Bu satıcının tüm işlemleri')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, _CategoryScope.thisOnly),
              child: const Text('Yalnız bu işlem')),
        ],
      ),
    );
    if (scope == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final categoryId = picked['id'] as String;
    setState(() => _isUpdating = true);
    String message;
    try {
      if (scope == _CategoryScope.allFromMerchant) {
        final changed = await _repository.learnCategory(
            counterparty: merchant, categoryId: categoryId);
        // Satıcı adı büyük/küçük harf farkıyla eşleşmese bile açılan işlem kesin güncellensin
        await _repository.updateTransactionCategory(txId, categoryId);
        message = changed > 1
            ? '$merchant: $changed işlem "$pickedName" oldu. Sonraki ekstrelerde de uygulanacak.'
            : 'Kategori "$pickedName" oldu. Bu satıcının sonraki işlemlerinde de uygulanacak.';
      } else {
        final ok =
            await _repository.updateTransactionCategory(txId, categoryId);
        if (!ok) {
          if (mounted) setState(() => _isUpdating = false);
          messenger.showSnackBar(const SnackBar(
              content: Text('Kayıt bulunamadı, kategori değişmedi.')));
          return;
        }
        message = 'Kategori "$pickedName" olarak değişti.';
      }
    } catch (e) {
      if (mounted) setState(() => _isUpdating = false);
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text('Kategori değiştirilemedi: $e')));
      return;
    }

    if (mounted) {
      setState(() {
        _isUpdating = false;
        _categoryId = categoryId;
        _categoryName = pickedName;
      });
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Kategori seçici: işlem türüne uygun grup önce; alt kategoriler üst kategorinin altında girintili.
  Future<Map<String, dynamic>?> _pickCategory(
      List<Map<String, dynamic>> categories) {
    final isExpense = transaction['isExpense'] == true;
    final byParent = <String?, List<Map<String, dynamic>>>{};
    for (final c in categories) {
      byParent.putIfAbsent(c['parent_id'] as String?, () => []).add(c);
    }
    final roots = byParent[null] ?? const <Map<String, dynamic>>[];
    final income =
        roots.where((c) => _incomeCategoryIds.contains(c['id'])).toList();
    final expense =
        roots.where((c) => !_incomeCategoryIds.contains(c['id'])).toList();
    final groups = isExpense
        ? [('Gider kategorileri', expense), ('Gelir kategorileri', income)]
        : [('Gelir kategorileri', income), ('Gider kategorileri', expense)];

    Widget tile(BuildContext ctx, Map<String, dynamic> c,
        {bool child = false}) {
      final selected = c['id'] == _categoryId;
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.only(left: child ? 40 : 16, right: 16),
        leading: CircleAvatar(
            radius: 7, backgroundColor: _parseColor(c['color_hex'])),
        title: Text(c['name'] as String,
            style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        trailing: selected
            ? const Icon(Icons.check_rounded, color: AppColors.actionPrimary)
            : null,
        onTap: () => Navigator.pop(ctx, c),
      );
    }

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Kategori seç',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              for (final (label, items) in groups)
                if (items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                  for (final c in items) ...[
                    tile(ctx, c),
                    for (final sub in byParent[c['id']] ??
                        const <Map<String, dynamic>>[])
                      tile(ctx, sub, child: true),
                  ],
                ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = transaction['title'] as String? ?? 'İşlem Detayı';
    final subtitle = transaction['subtitle'] as String? ?? '';
    final amount = transaction['amount'] as String? ?? '₺0,00';
    final isExpense = transaction['isExpense'] == true;
    final color = transaction['color'] as Color? ?? AppColors.actionPrimary;
    final icon = transaction['icon'] as IconData? ?? Icons.receipt_long_rounded;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
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
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık Çubuğu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tutar Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
                  isExpense ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isExpense ? 'ÖDENEN TUTAR' : 'GELİR TUTARI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isExpense
                        ? AppColors.expenseRed
                        : AppColors.incomeGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isExpense
                        ? AppColors.expenseRed
                        : AppColors.incomeGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detay Bilgi Satırları
          _buildDetailRow(
              Icons.calendar_today_rounded,
              'Tarih',
              subtitle.contains('•')
                  ? subtitle.split('•').last.trim()
                  : 'Güncel'),
          _buildDetailRow(
              Icons.category_rounded,
              'Kategori',
              _categoryName ??
                  (subtitle.contains('•')
                      ? subtitle.split('•').first.trim()
                      : 'Genel'),
              onTap: transaction['id'] == null ? null : _changeCategory,
              busy: _isUpdating),
          _buildDetailRow(Icons.smartphone_rounded, 'Saklandığı yer', 'Yalnız bu telefonda'),

          const SizedBox(height: 16),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete == null
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('İşlem silinsin mi?'),
                              content: const Text(
                                  'Kayıt bu telefondan kalıcı olarak silinir ve toplamlardan düşer. Ekstreyi yeniden yüklersen işlem geri gelir.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Vazgeç')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Sil',
                                        style: TextStyle(color: AppColors.expenseRed))),
                              ],
                            ),
                          );
                          if (ok != true || !context.mounted) return;
                          Navigator.pop(context);
                          onDelete!();
                        },
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.expenseRed),
                  label: const Text('Sil',
                      style: TextStyle(
                          color: AppColors.expenseRed,
                          fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Tamam',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {VoidCallback? onTap, bool busy = false}) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: onTap != null
                        ? AppColors.actionPrimary
                        : AppColors.textPrimary)),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.edit_rounded,
                  size: 14, color: AppColors.actionPrimary),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label değiştir',
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: row,
      ),
    );
  }
}
