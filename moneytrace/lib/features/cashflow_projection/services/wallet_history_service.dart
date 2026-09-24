// lib/features/cashflow_projection/services/wallet_history_service.dart

import '../../../core/database/app_database.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/bank_logo.dart';

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
  /// Taksitin okunduğu kartın bankası (accounts.institution_name)
  final String? bankName;

  const ActiveInstallment({
    required this.merchant,
    required this.currentInstallment,
    required this.totalInstallment,
    required this.monthlyCents,
    required this.remainingCents,
    this.bankName,
  });

  int get remainingCount => totalInstallment - currentInstallment;
}

/// Tek kartın son ekstredeki dönem borcu ve o ekstreden sonra bu karta kaydedilen ödemeler.
class CardDebt {
  final String accountId;
  final String bankName;
  final String? cardMask;
  final int statementDebtCents;
  final int paidSinceStatementCents;
  final String? dueDate; // ISO (yyyy-MM-dd), ekstreden

  const CardDebt({
    required this.accountId,
    required this.bankName,
    this.cardMask,
    required this.statementDebtCents,
    required this.paidSinceStatementCents,
    this.dueDate,
  });

  int get remainingCents =>
      (statementDebtCents - paidSinceStatementCents).clamp(0, statementDebtCents);
}

/// Son kart ekstresinden sonraki kart ödemelerini kartlara dağıtır; her ödeme en çok bir kez sayılır.
/// Hedef kart, ödeme kaydının açıklamasındaki banka adından bulunur ("Yapı Kredi kart ödemesi").
/// Banka adı hiçbir karta uymuyorsa ödeme yalnız tek kart varken o karta düşülür; aksi hâlde düşülmez.
/// Aynı bankanın birden çok kartı varsa (hangisine ödendiği bilinmez) ödeme, bu kartların hepsinin
/// son ekstresinden sonraysa bir kez sayılır ve ilk karta yazılır; toplam borç yine doğru kalır.
Map<String, int> allocateCardPayments({
  required List<({String accountId, String bankName, String periodEnd})> cards,
  required List<({String date, String description, int amountCents})> payments,
}) {
  final result = {for (final c in cards) c.accountId: 0};
  if (cards.isEmpty) return result;
  final bankKeys = {
    for (final c in cards) c.accountId: _bankKeys(c.bankName),
  };
  for (final p in payments) {
    final text = BankBrand.fold(p.description).replaceAll(' ', '');
    var candidates = cards
        .where((c) => bankKeys[c.accountId]!.any(text.contains))
        .toList();
    if (candidates.isEmpty && cards.length == 1) candidates = cards;
    if (candidates.isEmpty) continue;
    // Ödeme, aday kartların hepsinin son ekstresinden sonra olmalı (ekstrede zaten düşülmüş olmasın).
    final after = candidates.every((c) => p.date.compareTo(c.periodEnd) > 0);
    if (!after) continue;
    final target = candidates.first.accountId;
    result[target] = result[target]! + p.amountCents;
  }
  return result;
}

/// Ödeme açıklamasında bankayı tanımak için aranan yalın adlar (boşluksuz, sadeleştirilmiş).
List<String> _bankKeys(String bankName) {
  switch (BankBrand.of(bankName)?.slug) {
    case 'yapi_kredi':
      return const ['yapikredi', 'ykb'];
    case 'is_bankasi':
      return const ['isbank'];
    case 'garanti':
      return const ['garanti'];
    case 'akbank':
      return const ['akbank'];
    case 'enpara':
      return const ['enpara'];
    case 'ziraat':
      return const ['ziraat'];
    case 'halkbank':
      return const ['halkbank'];
    case 'vakifbank':
      return const ['vakif'];
    case 'qnb':
      return const ['qnb', 'finansbank'];
    default:
      final key = BankBrand.fold(bankName)
          .replaceAll(RegExp(r'(turkiye|bankasi|bank|a s|t a s|ve)'), ' ')
          .replaceAll(' ', '');
      return key.length >= 3 ? [key] : const [];
  }
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
  /// Kart bazında son ekstre borçları (banka logosuyla listelenir)
  final List<CardDebt> cardDebts;

  const WalletHistory({
    required this.months,
    required this.installments,
    required this.categoryChanges,
    this.accountBalanceCents,
    this.cardDebtCents,
    this.cardPaymentsSinceStatementCents = 0,
    this.cardDebts = const [],
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
             i.monthly_amount_cents AS monthly, i.remaining_amount_cents AS remaining,
             a.institution_name AS bank
      FROM installments i JOIN transactions t ON t.id = i.transaction_id
      LEFT JOIN accounts a ON a.id = t.account_id
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
        bankName: r['bank'] as String?,
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
      SELECT a.account_type AS type, s.statement_balance_cents AS bal, s.period_end AS period_end,
             s.due_date AS due_date, a.id AS account_id, a.institution_name AS bank, a.card_mask AS mask
      FROM accounts a
      JOIN statements s ON s.id = (
        SELECT s2.id FROM statements s2 WHERE s2.account_id = a.id
        ORDER BY COALESCE(s2.statement_date, s2.period_end) DESC, s2.created_at DESC LIMIT 1)
      WHERE a.account_type IN ('CHECKING', 'CREDIT_CARD') AND s.statement_balance_cents IS NOT NULL
    ''');
    int? accountBalance;
    int? cardDebt;
    final cardRows = <Map<String, Object?>>[];
    for (final r in balRows) {
      final bal = (r['bal'] as num).toInt();
      if (r['type'] == 'CHECKING') {
        accountBalance = (accountBalance ?? 0) + bal;
      } else {
        cardDebt = (cardDebt ?? 0) + bal;
        cardRows.add(r);
      }
    }

    // Son kart ekstrelerinden sonraki kart ödemeleri: kart bazında, her ödeme en çok bir kez.
    var paymentsSince = 0;
    final cardDebts = <CardDebt>[];
    if (cardRows.isNotEmpty) {
      final earliest = cardRows
          .map((r) => r['period_end'] as String)
          .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      final payRows = await db.rawQuery('''
        SELECT transaction_date AS d, billing_amount_cents AS amt,
               COALESCE(raw_description, '') || ' ' || COALESCE(clean_merchant, '') AS descr
        FROM transactions
        WHERE tx_kind = 'CARDPAYMENT' AND transaction_type = 'DEBIT' AND transaction_date > ?
      ''', [earliest]);
      final allocated = allocateCardPayments(
        cards: [
          for (final r in cardRows)
            (
              accountId: r['account_id'] as String,
              bankName: (r['bank'] as String?) ?? '',
              periodEnd: r['period_end'] as String,
            ),
        ],
        payments: [
          for (final p in payRows)
            (
              date: p['d'] as String,
              description: p['descr'] as String,
              amountCents: (p['amt'] as num).toInt(),
            ),
        ],
      );
      for (final r in cardRows) {
        final id = r['account_id'] as String;
        final paid = allocated[id] ?? 0;
        paymentsSince += paid;
        cardDebts.add(CardDebt(
          accountId: id,
          bankName: (r['bank'] as String?) ?? 'Kart',
          cardMask: r['mask'] as String?,
          statementDebtCents: (r['bal'] as num).toInt(),
          paidSinceStatementCents: paid,
          dueDate: r['due_date'] as String?,
        ));
      }
    }

    return WalletHistory(
      months: list,
      installments: installments,
      categoryChanges: changes,
      accountBalanceCents: accountBalance,
      cardDebtCents: cardDebt,
      cardPaymentsSinceStatementCents: paymentsSince,
      cardDebts: cardDebts,
    );
  }
}
