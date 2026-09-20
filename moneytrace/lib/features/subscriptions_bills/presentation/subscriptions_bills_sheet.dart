// lib/features/subscriptions_bills/presentation/subscriptions_bills_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../models/subscription_bill_item.dart';
import '../repositories/subscription_bill_repository.dart';

class SubscriptionsBillsSheet extends StatefulWidget {
  const SubscriptionsBillsSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SubscriptionsBillsSheet(),
    );
  }

  @override
  State<SubscriptionsBillsSheet> createState() => _SubscriptionsBillsSheetState();
}

class _SubscriptionsBillsSheetState extends State<SubscriptionsBillsSheet> {
  final SubscriptionBillRepository _repository = SubscriptionBillRepository.instance;

  @override
  void initState() {
    super.initState();
    _repository.load();
  }

  void _openAddBillModal() {
    final titleController = TextEditingController();
    final providerController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController(text: '15');
    BillCategory selectedCat = BillCategory.internet;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Yeni Abonelik / Fatura Ekle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),

                // Hızlı Şablonlar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip('Superonline', 'Turkcell Superonline Fiber', BillCategory.internet, '349', () {
                        setModalState(() {
                          providerController.text = 'Turkcell Superonline';
                          titleController.text = 'Superonline Fiber İnternet';
                          amountController.text = '349';
                          selectedCat = BillCategory.internet;
                        });
                      }),
                      _buildPresetChip('Vodafone', 'Vodafone Red Faturalı Hat', BillCategory.phone, '280', () {
                        setModalState(() {
                          providerController.text = 'Vodafone';
                          titleController.text = 'Vodafone GSM Faturası';
                          amountController.text = '280';
                          selectedCat = BillCategory.phone;
                        });
                      }),
                      _buildPresetChip('Netflix', 'Netflix Standart Plan', BillCategory.streaming, '149', () {
                        setModalState(() {
                          providerController.text = 'Netflix';
                          titleController.text = 'Netflix Aboneliği';
                          amountController.text = '149';
                          selectedCat = BillCategory.streaming;
                        });
                      }),
                      _buildPresetChip('Doğalgaz (PALGAZ)', 'PALGAZ Doğalgaz Faturası', BillCategory.utilities, '450', () {
                        setModalState(() {
                          providerController.text = 'PALGAZ';
                          titleController.text = 'PALGAZ Doğalgaz Faturası';
                          amountController.text = '450';
                          selectedCat = BillCategory.utilities;
                        });
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Abonelik / Fatura Adı',
                    hintText: 'Örn: Superonline İnternet, Vodafone',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: '₺ ',
                          labelText: 'Aylık Tutar',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: dayController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Ödeme Günü',
                          hintText: '1 - 31',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final cents = CurrencyNormalizer.toMinorUnits(amountController.text);
                      final day = int.tryParse(dayController.text) ?? 15;

                      final newBill = SubscriptionBillItem(
                        id: 'bill_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        provider: providerController.text.trim().isNotEmpty ? providerController.text.trim() : title,
                        category: selectedCat,
                        monthlyAmountCents: cents,
                        billingDayOfMonth: day.clamp(1, 31),
                      );

                      await _repository.addBill(newBill);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Aboneliği Kaydet', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String fullTitle, BillCategory cat, String amount, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        avatar: Icon(cat.iconData, size: 14, color: cat.color),
        backgroundColor: const Color(0xFFF1F5F9),
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SubscriptionBillItem>>(
      valueListenable: _repository.itemsNotifier,
      builder: (context, bills, _) {
        final totalCents = _repository.totalActiveMonthlyCents;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık ve Yeni Ekle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Abonelik ve Düzenli Faturalar',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      Text(
                        'İnternet, telefon, dijital yayın ve kamu faturaları',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.actionPrimary, size: 26),
                    onPressed: _openAddBillModal,
                    tooltip: 'Yeni Fatura Ekle',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Aylık Toplam Yük Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AYLIK SABİT FATURA YÜKÜ',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyNormalizer.formatCents(totalCents),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${bills.where((b) => b.isActive).length} Aktif Fatura',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Liste
              if (bills.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 10),
                        const Text('Kayıtlı Düzenli Fatura Bulunmuyor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Superonline, Vodafone veya Netflix gibi ödemelerinizi ekleyin.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _openAddBillModal,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ İlk Faturanızı Ekleyin'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = bills[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: item.category.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.category.iconData, color: item.category.color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: item.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                      decoration: item.isActive ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  Text(
                                    '${item.category.displayName} • Her ayın ${item.billingDayOfMonth}\'i',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyNormalizer.formatCents(item.monthlyAmountCents),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: item.isActive ? AppColors.textPrimary : AppColors.textMuted,
                                  ),
                                ),
                                Switch(
                                  value: item.isActive,
                                  activeColor: AppColors.actionPrimary,
                                  onChanged: (_) => _repository.toggleActive(item.id),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
