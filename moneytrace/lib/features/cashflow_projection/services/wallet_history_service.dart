// lib/features/cashflow_projection/services/wallet_history_service.dart

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/transaction_repository.dart';

/// Bir takvim ayının gerçekleşmiş gelir/gider özeti (tahmin yok).
class WalletMonth {
  final DateTime month; // ayın 1'i
  final int incomeCents;
  final int expenseCents;
  final int transactionCount;

  const WalletMonth({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.transactionCount,
  });

  int get netCents => incomeCents - expenseCents;
}

/// Ekstrelerden okunmuş, henüz bitmemiş taksit.
class ActiveInstallment {
  final String merchant;
  final int currentInstallment;
  final int totalInstallment;
  final int monthlyCents;
  final int remainingCents;

  const ActiveInstallment({
    required this.merchant,
    required this.currentInstallment,
    required this.totalInstallment,
    required this.monthlyCents,
    required this.remainingCents,
  });

  int get remainingCount => totalInstallment - currentInstallment;
}

class WalletHistory {
  final List<WalletMonth> months; // eskiden yeniye
  final List<ActiveInstallment> installments;
  final List<(String category, int thisMonthCents, int averageCents)> categoryChanges;
  /// Vadesiz hesapların son ekstredeki bakiyeleri toplamı (banka beyanı). Vadesiz ekstre yoksa null.
  final int? accountBalanceCents;
  /// Kartların son ekstredeki dönem borçları toplamı (banka beyanı). Kart ekstresi yoksa null.
  final int? cardDebtCents;
  /// Son kart ekstresinden sonra kaydedilen kart ödemeleri (manuel "Ödemeyi kaydet" dahil)
  final int cardPaymentsSinceStatementCents;

  const WalletHistory({
    required this.months,
    required this.installments,
    required this.categoryChanges,
    this.accountBalanceCents,
    this.cardDebtCents,
    this.cardPaymentsSinceStatementCents = 0,
  });

  int get remainingInstallmentsCents => installments.fold(0, (s, i) => s + i.remainingCents);
  int get monthlyInstallmentsCents => installments.fold(0, (s, i) => s + i.monthlyCents);
}

/// Cüzdan ekranı: yalnızca kayıtlı gerçek işlemlerden ve ekstrelerdeki taksitlerden beslenir.
/// Kart borcu ödemesi ve kendi hesaplar arası aktarım gelir/gider sayılmaz (çift sayım olmaz).
class WalletHistoryService {
  final AppDatabase _db;
  WalletHistoryService({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<WalletHistory> load({int months = 6, DateTime? now}) async {
    final db = await _db.database;
    final today = now ?? DateTime.now();
    final first = DateTime(today.year, today.month - (months - 1), 1);
    String ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

    // Ana sayfayla aynı kurallar: iade gideri azaltır, bordro+vadesiz maaşı bir kez sayılır
    final rows = await db.rawQuery('''
      SELECT strftime('%Y-%m', t.transaction_date) AS ym,
             SUM(CASE WHEN t.transaction_type = 'CREDIT' AND t.tx_kind <> 'REFUND' THEN t.billing_amount_cents ELSE 0 END) AS income,
             SUM(CASE WHEN t.transaction_type = 'DEBIT' THEN t.billing_amount_cents ELSE 0 END)
               - SUM(CASE WHEN t.transaction_type = 'CREDIT' AND t.tx_kind = 'REFUND' THEN t.billing_amount_cents ELSE 0 END) AS expense,
             COUNT(*) AS cnt
      FROM transactions t
      WHERE t.transaction_date >= ? AND t.tx_kind NOT IN ${TransactionRepository.neutralKindsSql}
        ${TransactionRepository.payslipDuplicateFilterSql}
      GROUP BY ym
    ''', [first.toIso8601String().substring(0, 10)]);
    final byMonth = {for (final r in rows) r['ym'] as String: r};

    final list = <WalletMonth>[];
    for (var i = 0; i < months; i++) {
      final m = DateTime(first.year, first.month + i, 1);
      final r = byMonth[ym(m)];
      list.add(WalletMonth(
        month: m,
        incomeCents: (r?['income'] as num?)?.toInt() ?? 0,
        expenseCents: (r?['expense'] as num?)?.toInt() ?? 0,
        transactionCount: (r?['cnt'] as num?)?.toInt() ?? 0,
      ));
    }

    // Her taksit planının EN GÜNCEL satırı (son taksit n/n dahil) seçilir, sonra bitmemişler alınır.
    // Önce filtrelenirse n/n satırı düşer ve (n-1)/n "kalan 1 ay" olarak sonsuza dek görünürdü.
    final instRows = await db.rawQuery('''
      SELECT t.clean_merchant AS merchant, i.current_installment AS cur, i.total_installment AS tot,
             i.monthly_amount_cents AS monthly, i.remaining_amount_cents AS remaining
      FROM installments i JOIN transactions t ON t.id = i.transaction_id
      WHERE i.total_installment > 0
        AND i.id = (
          SELECT i2.id FROM installments i2 JOIN transactions t2 ON t2.id = i2.transaction_id
          WHERE t2.account_id = t.account_id
            AND UPPER(t2.clean_merchant) = UPPER(t.clean_merchant)
            AND i2.total_installment = i.total_installment
          ORDER BY i2.current_installment DESC, i2.created_at DESC LIMIT 1)
        AND i.current_installment < i.total_installment
      ORDER BY t.transaction_date DESC
    ''');
    final installments = <ActiveInstallment>[];
    for (final r in instRows) {
      installments.add(ActiveInstallment(
        merchant: r['merchant'] as String,
        currentInstallment: (r['cur'] as num).toInt(),
        totalInstallment: (r['tot'] as num).toInt(),
        monthlyCents: (r['monthly'] as num).toInt(),
        remainingCents: (r['remaining'] as num?)?.toInt() ?? 0,
      ));
    }

    // Bu ayın kategori harcaması vs. önceki ayların ortalaması (İzci notu için)
    final catRows = await db.rawQuery('''
      SELECT COALESCE(c.name, 'Diğer') AS name, strftime('%Y-%m', t.transaction_date) AS ym,
             SUM(t.billing_amount_cents) AS total
      FROM transactions t LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.transaction_type = 'DEBIT' AND t.transaction_date >= ?
        AND t.tx_kind NOT IN ${TransactionRepository.neutralKindsSql}
      GROUP BY name, ym
    ''', [first.toIso8601String().substring(0, 10)]);
    final current = ym(DateTime(today.year, today.month, 1));
    final perCat = <String, Map<String, int>>{};
    for (final r in catRows) {
      perCat.putIfAbsent(r['name'] as String, () => {})[r['ym'] as String] = (r['total'] as num).toInt();
    }
    final pastMonths = months - 1;
    final changes = <(String, int, int)>[];
    perCat.forEach((name, values) {
      final thisMonth = values[current] ?? 0;
      final past = values.entries.where((e) => e.key != current).fold<int>(0, (s, e) => s + e.value);
      final avg = pastMonths > 0 ? past ~/ pastMonths : 0;
      changes.add((name, thisMonth, avg));
    });
    changes.sort((a, b) => (b.$2 - b.$3).compareTo(a.$2 - a.$3));

    // Bakiye tahmin edilmez: her hesabın en son ekstresinde bankanın yazdığı değer
    final balRows = await db.rawQuery('''
      SELECT a.account_type AS type, s.statement_balance_cents AS bal, s.period_end AS period_end, a.id AS account_id
      FROM accounts a
      JOIN statements s ON s.id = (
        SELECT s2.id FROM statements s2 WHERE s2.account_id = a.id
        ORDER BY COALESCE(s2.statement_date, s2.period_end) DESC, s2.created_at DESC LIMIT 1)
      WHERE a.account_type IN ('CHECKING', 'CREDIT_CARD') AND s.statement_balance_cents IS NOT NULL
    ''');
    int? accountBalance;
    int? cardDebt;
    var paymentsSince = 0;
    for (final r in balRows) {
      final bal = (r['bal'] as num).toInt();
      if (r['type'] == 'CHECKING') {
        accountBalance = (accountBalance ?? 0) + bal;
      } else {
        cardDebt = (cardDebt ?? 0) + bal;
        final paid = await db.rawQuery('''
          SELECT COALESCE(SUM(billing_amount_cents), 0) AS paid FROM transactions
          WHERE tx_kind = 'CARDPAYMENT' AND transaction_type = 'DEBIT' AND transaction_date > ?
        ''', [r['period_end']]);
        paymentsSince += ((paid.first['paid'] as num?) ?? 0).toInt();
      }
    }

    return WalletHistory(
      months: list,
      installments: installments,
      categoryChanges: changes,
      accountBalanceCents: accountBalance,
      cardDebtCents: cardDebt,
      cardPaymentsSinceStatementCents: paymentsSince,
    );
  }
}
