// lib/features/dashboard/presentation/widgets/transaction_detail_sheet.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/morphing_share_button.dart';

class TransactionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback? onDelete;

  const TransactionDetailSheet({
    Key? key,
    required this.transaction,
    this.onDelete,
  }) : super(key: key);

  static void show(BuildContext context, {required Map<String, dynamic> transaction, VoidCallback? onDelete}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionDetailSheet(
        transaction: transaction,
        onDelete: onDelete,
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
                      color: color.withOpacity(0.12),
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
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
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
              color: isExpense ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
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
                    color: isExpense ? AppColors.expenseRed : AppColors.incomeGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isExpense ? AppColors.expenseRed : AppColors.incomeGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detay Bilgi Satırları
          _buildDetailRow(Icons.calendar_today_rounded, 'Tarih', subtitle.contains('•') ? subtitle.split('•').last.trim() : 'Güncel'),
          _buildDetailRow(Icons.category_rounded, 'Kategori', subtitle.contains('•') ? subtitle.split('•').first.trim() : 'Genel'),
          _buildDetailRow(Icons.security_rounded, 'Kayıt Türü', 'Sıfır Bilgili Cihaz İçi Kasa (Zero-Knowledge)'),

          const SizedBox(height: 16),

          // Video 2: Morflayan Dekont Paylaşım Butonu (0% -> 100% -> Sosyal Butonlar)
          MorphingShareButton(
            fileName: '${title.replaceAll(" ", "_")}_dekont.pdf',
            label: 'Dekontu İndir & Paylaş',
            accentColor: color,
            onDownloadComplete: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.incomeGreen,
                  content: Text('$title dekontu hazırlandı ve paylaşıldı.'),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onDelete != null) onDelete!();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expenseRed),
                  label: const Text('Sil', style: TextStyle(color: AppColors.expenseRed, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
