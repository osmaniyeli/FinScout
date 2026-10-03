// lib/features/profile/presentation/uploaded_statements_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/bank_logo.dart';

/// Belge türü kodunu (StatementDocumentResult.documentType) okunur Türkçe etikete çevirir.
String documentTypeLabel(String type) {
  switch (type) {
    case 'CREDIT_CARD':
      return 'Kredi Kartı';
    case 'CHECKING':
      return 'Vadesiz Hesap';
    case 'PAYSLIP':
      return 'Bordro';
    default:
      return type;
  }
}

String _day(DateTime x) =>
    '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}.${x.year}';

/// "10.01.2026 – 09.02.2026" biçiminde dönem aralığı.
String formatPeriod(DateTime start, DateTime end) => '${_day(start)} – ${_day(end)}';

/// "27.09.2026" biçiminde tek tarih.
String formatDate(DateTime x) => _day(x);

/// Profil ekranındaki önizlemede gösterilmeyen belgeler için tam liste.
/// Zaten çekilmiş (yerel SQLite, hızlı) [statements] listesini alır; ayrıca sorgu yapmaz.
class UploadedStatementsScreen extends StatelessWidget {
  final List<UploadedStatement> statements;

  const UploadedStatementsScreen({super.key, required this.statements});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Yüklediğim Belgeler (${statements.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // Uzun listede performans için ListView.builder (separated) — tamamı önceden bellekte,
      // yalnız görünen satırlar inşa edilir.
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: statements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => StatementCard(statement: statements[index]),
      ),
    );
  }
}

/// Tek bir yüklenmiş belgenin kartı: banka/kurum rozeti, tür + dönem, yükleme tarihi, işlem sayısı.
/// [showBorder] false olursa (profil önizlemesindeki gibi, zaten bir üst kartın içindeyse)
/// kendi çerçeve/arka planını çizmez — iç içe kart görünümünü önler.
class StatementCard extends StatelessWidget {
  final UploadedStatement statement;
  final EdgeInsetsGeometry padding;
  final bool showBorder;

  const StatementCard({
    super.key,
    required this.statement,
    this.padding = const EdgeInsets.all(14),
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BankLogo(bankName: statement.institution, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${statement.institution} · ${documentTypeLabel(statement.documentType)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  formatPeriod(statement.periodStart, statement.periodEnd),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Yüklendi: ${formatDate(statement.uploadedAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  statement.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${statement.transactionCount} işlem',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    return showBorder
        ? FinanceCard(
            padding: padding,
            color: Colors.white,
            borderRadius: 16,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [],
            child: row,
          )
        : Padding(padding: padding, child: row);
  }
}
