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

  const WalletHistory({required this.months, required this.installments, required this.categoryChanges});

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

    final rows = await db.rawQuery('''
      SELECT strftime('%Y-%m', transaction_date) AS ym,
             SUM(CASE WHEN transaction_type = 'CREDIT' THEN billing_amount_cents ELSE 0 END) AS income,
             SUM(CASE WHEN transaction_type = 'DEBIT' THEN billing_amount_cents ELSE 0 END) AS expense,
             COUNT(*) AS cnt
      FROM transactions
      WHERE transaction_date >= ? AND tx_kind NOT IN ${TransactionRepository.neutralKindsSql}
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

    // Her taksitli işlem için en güncel ekstredeki durum (aynı işlem her ay yeniden görünür)
    final instRows = await db.rawQuery('''
      SELECT t.clean_merchant AS merchant, i.current_installment AS cur, i.total_installment AS tot,
             i.monthly_amount_cents AS monthly, i.remaining_amount_cents AS remaining
      FROM installments i JOIN transactions t ON t.id = i.transaction_id
      WHERE i.total_installment > 0 AND i.current_installment < i.total_installment
      ORDER BY t.transaction_date DESC, i.current_installment DESC
    ''');
    final seen = <String>{};
    final installments = <ActiveInstallment>[];
    for (final r in instRows) {
      final key = '${r['merchant']}|${r['tot']}|${r['monthly']}';
      if (!seen.add(key)) continue;
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

    return WalletHistory(months: list, installments: installments, categoryChanges: changes);
  }
}
