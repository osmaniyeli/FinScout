// lib/features/assets_portfolio/presentation/widgets/card_payment_flow.dart

import 'package:flutter/material.dart';
import '../../../../core/database/repositories/transaction_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/bank_logo.dart';
import 'credit_card_action_sheet.dart';

/// "Kart ödemesi kaydet" akışı: Varlıklar › Kartlar'daki "Ödemeyi kaydet" sayfasının aynısı,
/// başka sekmelerden (Cüzdan + menüsü) de açılabilsin diye ayrı tutulur.
class CardPaymentFlow {
  CardPaymentFlow._();

  /// Kart ödemesini kayda geçirir (nötr CARDPAYMENT: gelir/gider sayılmaz). Hata fırlatılır.
  /// Başlıkta bankanın adı durur; Cüzdan ödemeyi bu adla doğru karta düşer.
  static Future<void> record(
    TransactionRepository repository,
    Map<String, dynamic> card,
    int paidCents,
    PaymentSource source,
    DateTime date,
  ) async {
    final bank = (card['bank'] ?? card['name']).toString();
    await repository.saveManualTransaction(
      title: '$bank kart ödemesi',
      amountCents: paidCents,
      isExpense: true,
      categoryId: 'cat_card_payment',
      date: date,
      note: '$bank kart ödemesi (${source.label})',
      txKind: 'CARDPAYMENT',
      accountId: source.accountId,
    );
  }

  static String? _formatIsoDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  /// Ekstresi yüklenmiş kredi kartlarından birini seçtirir (tek kartsa doğrudan) ve ödeme sayfasını açar.
  static Future<void> start(BuildContext context,
      {TransactionRepository? repository}) async {
    final repo = repository ?? TransactionRepository();
    final List<Map<String, dynamic>> accounts;
    try {
      accounts = await repo.getAccountsWithLatestStatement();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kart bilgileri okunamadı. Lütfen tekrar dene.')));
      }
      return;
    }
    if (!context.mounted) return;

    final cards = <Map<String, dynamic>>[
      for (final a in accounts.where((a) => a['account_type'] == 'CREDIT_CARD'))
        {
          'account_id': a['id'],
          'name': (a['institution_name'] as String?) ?? 'Kart',
          'bank': (a['institution_name'] as String?) ?? 'Kart',
          'mask': ((a['card_mask'] as String?) ?? '').isNotEmpty
              ? a['card_mask']
              : 'Kredi Kartı',
          'debt_cents': (a['statement_balance_cents'] as num?)?.toInt(),
          'minimum_cents': (a['minimum_payment_cents'] as num?)?.toInt(),
          'due': _formatIsoDate(a['due_date'] as String?) ?? '—',
          'color': const Color(0xFF7C3AED),
        },
    ];
    final sources = <PaymentSource>[
      const PaymentSource(accountId: null, label: 'Nakit Cüzdan'),
      for (final a in accounts.where((a) => a['account_type'] == 'CHECKING'))
        PaymentSource(
          accountId: a['id'] as String,
          label: [
            '${a['institution_name'] ?? 'Banka'} vadesiz',
            if (((a['card_mask'] as String?) ?? '').isNotEmpty) a['card_mask'],
          ].join(' • '),
        ),
    ];

    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Kayıtlı kredi kartı yok. Önce kartın ekstresini yükle; ödeme o karta kaydedilir.')));
      return;
    }

    Map<String, dynamic>? card = cards.length == 1 ? cards.first : null;
    card ??= await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Hangi karta ödeme yaptın?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 8),
              for (final c in cards)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: BankLogo(bankName: c['bank'] as String, size: 36),
                  title: Text('${c['name']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    [
                      '${c['mask']}',
                      if (c['debt_cents'] != null)
                        'Dönem borcu ${CurrencyNormalizer.formatCents(c['debt_cents'] as int)}',
                    ].join(' • '),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  onTap: () => Navigator.pop(ctx, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (card == null || !context.mounted) return;
    final chosen = card;
    await CreditCardActionSheet.show(
      context,
      card: chosen,
      sourceAccounts: sources,
      onPaymentRecorded: (paidCents, source, date) =>
          record(repo, chosen, paidCents, source, date),
    );
  }
}
