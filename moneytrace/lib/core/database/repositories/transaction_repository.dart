import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../parser/models/parsed_models.dart';
import '../../../features/wallets/models/wallet.dart';
import '../../../features/wallets/repositories/wallet_repository.dart';

class TransactionRepository {
  final AppDatabase _dbProvider;

  TransactionRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  /// Ekstre dosyasının daha önce yüklenip yüklenmediğini SHA256 ile kontrol eder.
  Future<bool> isStatementAlreadyImported(String fileSha256) async {
    final db = await _dbProvider.database;
    final res = await db.query(
      'statements',
      columns: ['id'],
      where: 'file_sha256 = ?',
      whereArgs: [fileSha256],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  /// Gelir/gider analizlerine girmeyen işlem türleri: kart borcu ödemesi (harcama zaten kart ekstresinde
  /// sayıldı) ve kişinin kendi hesapları arası aktarımı. Aksi halde aynı para iki kez sayılır.
  static const String neutralKindsSql = "('CARDPAYMENT','OWNTRANSFER')";

  /// Parser çıktısını tek veritabanı transaction'ı içinde kaydeder.
  /// Aynı işlem (aynı hesap, tarih, tutar, açıklama) tekrar içe aktarılırsa atlanır.
  Future<StatementSaveResult> saveStatementResult({
    required StatementDocumentResult result,
    required String fileSha256,
    String? fileName,
    String? targetWalletId,
  }) async {
    final db = await _dbProvider.database;
    var inserted = 0;
    var skipped = 0;
    var insertedDebit = 0;
    var insertedCredit = 0;

    await db.transaction((txn) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      String day(DateTime d) => d.toIso8601String().split('T')[0];

      // 1. Hesap (Account) oluştur veya bul
      final accountId =
          'acc_${result.institution.toLowerCase().replaceAll(' ', '_')}_${result.accountIdentifier.replaceAll(' ', '')}';
      await txn.insert(
        'accounts',
        {
          'id': accountId,
          'institution_name': result.institution,
          'account_type': result.documentType,
          'account_name': '${result.institution} Hesabı',
          'card_mask': result.accountIdentifier,
          'currency_code': 'TRY',
          'created_at': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      // 2. Ekstre kaydı + banka beyanları (ödeme düzeni)
      final statementId = 'stmt_$nowMs';
      final summary = result.summary;
      await txn.insert('statements', {
        'id': statementId,
        'account_id': accountId,
        'file_sha256': fileSha256,
        'file_name': fileName ?? 'ekstre.pdf',
        'period_start': day(result.periodStart),
        'period_end': day(result.periodEnd),
        'total_spend_cents': result.totalDebitCents,
        'total_income_cents': result.totalCreditCents,
        'total_tax_cents': result.totalTaxCents,
        'is_processed': 1,
        'statement_date': summary.statementDate == null ? null : day(summary.statementDate!),
        'due_date': summary.dueDate == null ? null : day(summary.dueDate!),
        'statement_balance_cents': summary.statementBalanceCents,
        'minimum_payment_cents': summary.minimumPaymentCents,
        'is_reconciled': result.reconciliation.isBalanced ? 1 : 0,
        'created_at': nowMs,
      });

      for (final (i, planned) in summary.scheduledPayments.indexed) {
        await txn.insert('scheduled_payments', {
          'id': '${statementId}_plan_$i',
          'statement_id': statementId,
          'account_id': accountId,
          'due_date': day(planned.date),
          'description': planned.description,
          'amount_cents': planned.amountCents,
          'created_at': nowMs,
        });
      }

      // 3. İşlemler (mükerrer korumalı), taksitler ve vergiler
      final occurrences = <String, int>{};
      for (final (index, record) in result.records.indexed) {
        final isDebit = record.type == ParsedTransactionType.debit;
        final baseKey = [
          accountId,
          day(record.date),
          record.signedAmountCents,
          record.rawDescription.toUpperCase().replaceAll(RegExp(r'\s+'), ' '),
          record.installment?.currentInstallment ?? 0,
        ].join('|');
        // Aynı gün aynı tutarlı gerçek tekrarlar (ör. iki toplu taşıma geçişi) ayrı kayıt olarak kalsın
        final occurrence = occurrences.update(baseKey, (n) => n + 1, ifAbsent: () => 0);
        final fingerprint = sha1.convert(utf8.encode('$baseKey#$occurrence')).toString();

        final txId = 'tx_${nowMs}_$index';
        final rowId = await txn.insert(
          'transactions',
          {
            'id': txId,
            'account_id': accountId,
            'statement_id': statementId,
            'transaction_date': day(record.date),
            'transaction_type': isDebit ? 'DEBIT' : 'CREDIT',
            'raw_description': record.rawDescription,
            'clean_merchant': record.cleanMerchant.isNotEmpty ? record.cleanMerchant : record.rawDescription,
            'category_id': record.categoryId,
            'billing_amount_cents': record.billingAmountCents,
            'billing_currency': record.billingCurrency,
            'original_amount_cents': record.originalAmountCents,
            'original_currency': record.originalCurrency,
            'exchange_rate': record.exchangeRate,
            'is_recurring': 0,
            'is_tax_deductible': record.taxes.isNotEmpty ? 1 : 0,
            'tx_kind': record.kind.code,
            'counterparty': record.counterparty,
            'sector': record.sector,
            'balance_after_cents': record.balanceAfterCents,
            'fingerprint': fingerprint,
            'created_at': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (rowId == 0) {
          skipped++;
          continue;
        }
        inserted++;
        if (record.kind != TransactionKind.cardPayment && record.kind != TransactionKind.ownTransfer) {
          if (isDebit) {
            insertedDebit += record.billingAmountCents;
          } else {
            insertedCredit += record.billingAmountCents;
          }
        }

        if (record.installment != null) {
          final inst = record.installment!;
          await txn.insert('installments', {
            'id': 'inst_$txId',
            'transaction_id': txId,
            'current_installment': inst.currentInstallment,
            'total_installment': inst.totalInstallment,
            'remaining_amount_cents': inst.remainingAmountCents,
            'monthly_amount_cents': inst.monthlyAmountCents,
            'due_date': summary.dueDate == null ? day(record.date) : day(summary.dueDate!),
            'created_at': nowMs,
          });
        }

        for (final tax in record.taxes) {
          await txn.insert('tax_deductions', {
            'id': 'tax_${txId}_${tax.taxType}',
            'transaction_id': txId,
            'statement_id': statementId,
            'tax_type': tax.taxType,
            'amount_cents': tax.amountCents,
            'tax_date': day(record.date),
            'created_at': nowMs,
          });
        }
      }
    });

    if (targetWalletId != null && inserted > 0) {
      try {
        await WalletRepository.instance.load();
        final wallet = WalletRepository.instance.wallets.firstWhere(
          (w) => w.id == targetWalletId,
          orElse: () => WalletRepository.instance.getConsolidatedWallet(),
        );
        // Kredi kartında harcama borcu artırır, ödeme/iade azaltır; vadesizde tersi
        final netChange = wallet.type == WalletType.creditCard
            ? insertedDebit - insertedCredit
            : insertedCredit - insertedDebit;
        await WalletRepository.instance.updateBalance(targetWalletId, wallet.balanceCents + netChange);
      } catch (_) {}
    }

    return StatementSaveResult(inserted: inserted, skippedDuplicates: skipped);
  }

  /// Kullanıcının kategori düzeltmelerinden öğrenilmiş kurallar (karşı taraf kalıbı → kategori).
  Future<Map<String, String>> loadUserCategoryRules() async {
    final db = await _dbProvider.database;
    final rows = await db.query('merchant_rules', columns: ['raw_pattern', 'user_category_id']);
    return {for (final r in rows) r['raw_pattern'] as String: r['user_category_id'] as String};
  }

  /// Kullanıcı bir işlemin kategorisini değiştirdiğinde: kuralı kaydeder ve aynı karşı taraftaki
  /// geçmiş işlemleri de günceller. Sonraki ekstrelerde bu kural otomatik uygulanır.
  Future<int> learnCategory({required String counterparty, required String categoryId}) async {
    final pattern = counterparty.trim().toUpperCase();
    if (pattern.length < 3) return 0;
    final db = await _dbProvider.database;
    await db.insert(
      'merchant_rules',
      {
        'id': 'rule_${sha1.convert(utf8.encode(pattern)).toString().substring(0, 16)}',
        'raw_pattern': pattern,
        'user_category_id': categoryId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return db.update(
      'transactions',
      {'category_id': categoryId},
      where: 'UPPER(counterparty) = ? OR UPPER(clean_merchant) = ?',
      whereArgs: [pattern, pattern],
    );
  }

  /// Yaklaşan ödemeler: kart son ödeme tarihleri (dönem borcu + asgari) ve ekstrelerdeki planlı talimatlar.
  Future<List<Map<String, dynamic>>> getUpcomingPayments({DateTime? from}) async {
    final db = await _dbProvider.database;
    final today = (from ?? DateTime.now()).toIso8601String().split('T')[0];
    return db.rawQuery('''
      SELECT s.due_date AS due_date,
             a.institution_name || ' kart borcu' AS description,
             s.statement_balance_cents AS amount_cents,
             s.minimum_payment_cents AS minimum_cents,
             'CARD_DUE' AS kind
      FROM statements s JOIN accounts a ON a.id = s.account_id
      WHERE s.due_date IS NOT NULL AND s.due_date >= ? AND COALESCE(s.statement_balance_cents, 0) > 0
      UNION ALL
      SELECT p.due_date, p.description, p.amount_cents, NULL, p.kind
      FROM scheduled_payments p
      WHERE p.due_date >= ?
      ORDER BY due_date ASC
    ''', [today, today]);
  }

  /// Manuel Hızlı Giriş (Quick Entry) kaydı ekler.
  Future<void> saveManualTransaction({
    required String title,
    required int amountCents,
    required bool isExpense,
    required String categoryId,
    required DateTime date,
    String? note,
    String txKind = 'OTHER',
  }) async {
    final db = await _dbProvider.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final txId = 'manual_tx_$nowMs';
    const accountId = 'acc_manual_cash';

    await db.insert(
      'accounts',
      {
        'id': accountId,
        'institution_name': 'Nakit & Manuel',
        'account_type': 'CASH',
        'account_name': 'Nakit Cüzdan',
        'card_mask': 'CASH',
        'currency_code': 'TRY',
        'created_at': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert('transactions', {
      'id': txId,
      'account_id': accountId,
      'statement_id': null,
      'transaction_date': date.toIso8601String().split('T')[0],
      'transaction_type': isExpense ? 'DEBIT' : 'CREDIT',
      'raw_description': note ?? title,
      'clean_merchant': title,
      'category_id': categoryId,
      'billing_amount_cents': amountCents,
      'billing_currency': 'TRY',
      'is_recurring': 0,
      'is_tax_deductible': 0,
      'tx_kind': txKind,
      'counterparty': title,
      'created_at': nowMs,
    });
  }

  /// Döneme ait toplam gider, toplam gelir ve net farkı hesaplar
  Future<Map<String, int>> getMonthlySummary(
      {required String yearMonth}) async {
    final db = await _dbProvider.database;
    final res = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN transaction_type = 'DEBIT' THEN billing_amount_cents ELSE 0 END) as total_debit,
        SUM(CASE WHEN transaction_type = 'CREDIT' THEN billing_amount_cents ELSE 0 END) as total_credit
      FROM transactions
      WHERE transaction_date LIKE ? AND tx_kind NOT IN $neutralKindsSql
    ''', ['$yearMonth%']);

    final debit = (res.first['total_debit'] as num?)?.toInt() ?? 0;
    final credit = (res.first['total_credit'] as num?)?.toInt() ?? 0;

    return {
      'totalDebitCents': debit,
      'totalCreditCents': credit,
      'netDifferenceCents': credit - debit,
    };
  }

  /// Son işlemleri getirir (opsiyonel olarak seçilen aya göre filtreler)
  Future<List<Map<String, dynamic>>> getRecentTransactions(
      {int limit = 30, String? yearMonth}) async {
    final db = await _dbProvider.database;
    if (yearMonth != null && yearMonth.isNotEmpty) {
      return await db.rawQuery('''
        SELECT 
          t.id,
          t.transaction_date,
          t.transaction_type,
          t.clean_merchant,
          t.billing_amount_cents,
          c.name as category_name,
          c.icon_name,
          c.color_hex,
          i.current_installment,
          i.total_installment,
          i.monthly_amount_cents,
          i.remaining_amount_cents
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        LEFT JOIN installments i ON t.id = i.transaction_id
        WHERE t.transaction_date LIKE ?
        ORDER BY t.transaction_date DESC, t.created_at DESC
        LIMIT ?
      ''', ['$yearMonth%', limit]);
    }

    return await db.rawQuery('''
      SELECT 
        t.id,
        t.transaction_date,
        t.transaction_type,
        t.clean_merchant,
        t.billing_amount_cents,
        c.name as category_name,
        c.icon_name,
        c.color_hex,
        i.current_installment,
        i.total_installment,
        i.monthly_amount_cents,
        i.remaining_amount_cents
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN installments i ON t.id = i.transaction_id
      ORDER BY t.transaction_date DESC, t.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Gelecek / Yaklaşan taksit ödemelerini getirir (kalan taksitler: current < total)
  Future<List<Map<String, dynamic>>> getUpcomingInstallments(
      {int limit = 10}) async {
    final db = await _dbProvider.database;
    return await db.rawQuery('''
      SELECT 
        i.id as installment_id,
        t.clean_merchant,
        i.current_installment,
        i.total_installment,
        i.monthly_amount_cents,
        i.remaining_amount_cents,
        i.due_date,
        c.color_hex
      FROM installments i
      JOIN transactions t ON i.transaction_id = t.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE i.current_installment < i.total_installment
      ORDER BY i.due_date ASC
      LIMIT ?
    ''', [limit]);
  }

  /// Kategori bazlı gerçek harcama analizi ve yüzdelerini hesaplar
  Future<List<Map<String, dynamic>>> getCategorySpendingAnalysis(
      {String? yearMonth}) async {
    final db = await _dbProvider.database;
    final whereClause = yearMonth != null && yearMonth.isNotEmpty
        ? "WHERE t.transaction_type = 'DEBIT' AND t.tx_kind NOT IN $neutralKindsSql AND t.transaction_date LIKE ?"
        : "WHERE t.transaction_type = 'DEBIT' AND t.tx_kind NOT IN $neutralKindsSql";
    final whereArgs =
        yearMonth != null && yearMonth.isNotEmpty ? ['$yearMonth%'] : [];

    final rows = await db.rawQuery('''
      SELECT 
        COALESCE(c.name, 'Genel') as name,
        COALESCE(c.color_hex, '#64748B') as color_hex,
        SUM(t.billing_amount_cents) as total_cents
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      $whereClause
      GROUP BY t.category_id
      ORDER BY total_cents DESC
    ''', whereArgs);

    if (rows.isEmpty) return [];

    int grandTotalCents = 0;
    for (final r in rows) {
      grandTotalCents += ((r['total_cents'] as num?)?.toInt() ?? 0);
    }

    if (grandTotalCents <= 0) return [];

    return rows.map((r) {
      final cents = ((r['total_cents'] as num?)?.toInt() ?? 0);
      final pct = ((cents / grandTotalCents) * 100).round();
      final hex = (r['color_hex'] as String?) ?? '#64748B';
      return {
        'name': r['name'] as String,
        'cents': cents,
        'percentage': pct,
        'color_hex': hex,
      };
    }).toList();
  }

  /// Gerçek aylık harcama trendlerini (Son 6 ay) hesaplar
  Future<List<Map<String, dynamic>>> getMonthlyTrendsAnalysis() async {
    final db = await _dbProvider.database;
    final rows = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', transaction_date) as year_month,
        SUM(billing_amount_cents) as total_cents
      FROM transactions
      WHERE transaction_type = 'DEBIT' AND tx_kind NOT IN $neutralKindsSql
      GROUP BY year_month
      ORDER BY year_month DESC
      LIMIT 6
    ''');

    if (rows.isEmpty) return [];

    final reversed = rows.reversed.toList();
    int maxCents = 0;
    for (final r in reversed) {
      final cents = ((r['total_cents'] as num?)?.toInt() ?? 0);
      if (cents > maxCents) maxCents = cents;
    }

    const monthShortNames = [
      'OCA',
      'ŞUB',
      'MAR',
      'NİS',
      'MAY',
      'HAZ',
      'TEM',
      'AĞU',
      'EYL',
      'EKİ',
      'KAS',
      'ARA'
    ];

    return reversed.map((r) {
      final ym = r['year_month'] as String? ?? '';
      final parts = ym.split('-');
      String displayMonth = ym;
      if (parts.length == 2) {
        final mIdx = int.tryParse(parts[1]) ?? 1;
        if (mIdx >= 1 && mIdx <= 12) {
          displayMonth = monthShortNames[mIdx - 1];
        }
      }
      final cents = ((r['total_cents'] as num?)?.toInt() ?? 0);
      final ratio = maxCents > 0 ? (cents / maxCents) : 0.0;
      return {
        'month': displayMonth,
        'year_month': ym,
        'cents': cents,
        'ratio': ratio,
      };
    }).toList();
  }

  /// KDV ve vergi kesintisi toplamlarını hesaplar
  Future<Map<String, dynamic>> getVatAndTaxSummary({String? yearMonth}) async {
    final db = await _dbProvider.database;

    final taxRows = await db.rawQuery('''
      SELECT 
        tax_type,
        SUM(amount_cents) as total_cents
      FROM tax_deductions
      GROUP BY tax_type
    ''');

    int totalVatCents = 0;
    int totalIncomeTaxCents = 0;
    int totalSgkCents = 0;
    int totalOtherTaxCents = 0;

    for (final r in taxRows) {
      final type = (r['tax_type'] as String? ?? '').toUpperCase();
      final cents = ((r['total_cents'] as num?)?.toInt() ?? 0);
      if (type.contains('KDV') || type.contains('VAT')) {
        totalVatCents += cents;
      } else if (type.contains('GELİR') || type.contains('INCOME')) {
        totalIncomeTaxCents += cents;
      } else if (type.contains('SGK')) {
        totalSgkCents += cents;
      } else {
        totalOtherTaxCents += cents;
      }
    }

    final deductibleRow = await db.rawQuery('''
      SELECT SUM(billing_amount_cents) as total_cents
      FROM transactions
      WHERE is_tax_deductible = 1 AND transaction_type = 'DEBIT'
    ''');
    final deductibleCents =
        ((deductibleRow.firstOrNull?['total_cents'] as num?)?.toInt() ?? 0);

    return {
      'vat_cents': totalVatCents,
      'income_tax_cents': totalIncomeTaxCents,
      'sgk_cents': totalSgkCents,
      'other_tax_cents': totalOtherTaxCents,
      'deductible_cents': deductibleCents,
      'total_tax_cents': totalVatCents +
          totalIncomeTaxCents +
          totalSgkCents +
          totalOtherTaxCents,
    };
  }

  /// Tüm veritabanı tablolarını dışa aktarma (CSV & JSON Yedek) için çeker
  Future<Map<String, dynamic>> getAllDataForExport() async {
    final db = await _dbProvider.database;

    final accounts = await db.query('accounts');
    final statements = await db.query('statements');
    final installments = await db.query('installments');
    final taxes = await db.query('tax_deductions');

    final transactionsWithDetails = await db.rawQuery('''
      SELECT 
        t.*,
        c.name as category_name,
        a.institution_name,
        a.card_mask,
        i.current_installment,
        i.total_installment,
        tax.tax_type,
        tax.amount_cents as tax_amount_cents
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN installments i ON i.transaction_id = t.id
      LEFT JOIN tax_deductions tax ON tax.transaction_id = t.id
      ORDER BY t.transaction_date DESC, t.created_at DESC
    ''');

    return {
      'accounts': accounts,
      'statements': statements,
      'transactions': transactionsWithDetails,
      'installments': installments,
      'tax_deductions': taxes,
    };
  }

  /// JSON Yedeğini Atomik Transaction ile Geri Yükler
  Future<void> restoreVaultBackup(Map<String, dynamic> data) async {
    final db = await _dbProvider.database;

    await db.transaction((txn) async {
      // 1. Hesaplar
      final accounts = data['accounts'] as List<dynamic>? ?? [];
      for (final a in accounts) {
        if (a is Map<String, dynamic>) {
          await txn.insert('accounts', a,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 2. Ekstreler
      final statements = data['statements'] as List<dynamic>? ?? [];
      for (final s in statements) {
        if (s is Map<String, dynamic>) {
          await txn.insert('statements', s,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 3. İşlemler
      final transactions = data['transactions'] as List<dynamic>? ?? [];
      for (final t in transactions) {
        if (t is Map<String, dynamic>) {
          // Join kolonlarını temizle, sadece tablo kolonlarını ekle
          final cleanTx = Map<String, dynamic>.from(t)
            ..remove('category_name')
            ..remove('institution_name')
            ..remove('card_mask')
            ..remove('current_installment')
            ..remove('total_installment')
            ..remove('tax_type')
            ..remove('tax_amount_cents');

          await txn.insert('transactions', cleanTx,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 4. Taksitler
      final installments = data['installments'] as List<dynamic>? ?? [];
      for (final i in installments) {
        if (i is Map<String, dynamic>) {
          await txn.insert('installments', i,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 5. Vergiler
      final taxes = data['tax_deductions'] as List<dynamic>? ?? [];
      for (final tax in taxes) {
        if (tax is Map<String, dynamic>) {
          await txn.insert('tax_deductions', tax,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  /// Kullanıcı verilerini tamamen sıfırlar (0 TL başlangıç & temiz test modu için)
  Future<void> clearAllUserData() async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn.delete('tax_deductions');
      await txn.delete('installments');
      await txn.delete('transactions');
      await txn.delete('statements');
      await txn.delete('accounts');
    });
  }

  /// Kayıtlı tüm hesapları ve kartları getirir
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await _dbProvider.database;
    return await db.query('accounts', orderBy: 'created_at DESC');
  }
}

class StatementSaveResult {
  final int inserted;
  final int skippedDuplicates;
  const StatementSaveResult({required this.inserted, required this.skippedDuplicates});
}
