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

  /// Parser çıktısı olan StatementDocumentResult nesnesini tek transaction içinde veritabanına kaydeder.
  Future<void> saveStatementResult({
    required StatementDocumentResult result,
    required String fileSha256,
    String? fileName,
    String? targetWalletId,
  }) async {
    final db = await _dbProvider.database;

    await db.transaction((txn) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Hesap (Account) oluştur veya bul
      final accountId = 'acc_${result.institution.toLowerCase().replaceAll(' ', '_')}_${result.accountIdentifier.replaceAll(' ', '')}';
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

      // 2. Ekstre (Statement) Kaydı
      final statementId = 'stmt_$nowMs';
      await txn.insert('statements', {
        'id': statementId,
        'account_id': accountId,
        'file_sha256': fileSha256,
        'file_name': fileName ?? 'ekstre.pdf',
        'period_start': result.periodStart.toIso8601String().split('T')[0],
        'period_end': result.periodEnd.toIso8601String().split('T')[0],
        'total_spend_cents': result.totalDebitCents,
        'total_income_cents': result.totalCreditCents,
        'total_tax_cents': result.totalTaxCents,
        'is_processed': 1,
        'created_at': nowMs,
      });

      // 3. İşlem Satırları (Transactions), Taksitler ve Vergiler
      int index = 0;
      for (final record in result.records) {
        index++;
        final txId = 'tx_${nowMs}_$index';
        final isDebit = record.type == ParsedTransactionType.debit;

        await txn.insert('transactions', {
          'id': txId,
          'account_id': accountId,
          'statement_id': statementId,
          'transaction_date': record.date.toIso8601String().split('T')[0],
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
          'created_at': nowMs,
        });

        // Varsa taksit detayı
        if (record.installment != null) {
          final inst = record.installment!;
          await txn.insert('installments', {
            'id': 'inst_${txId}',
            'transaction_id': txId,
            'current_installment': inst.currentInstallment,
            'total_installment': inst.totalInstallment,
            'remaining_amount_cents': inst.remainingAmountCents,
            'monthly_amount_cents': inst.monthlyAmountCents,
            'due_date': record.date.toIso8601String().split('T')[0],
            'created_at': nowMs,
          });
        }

        // Varsa vergi detayı (BSMV, KKDF, Stopaj, vb.)
        for (final tax in record.taxes) {
          await txn.insert('tax_deductions', {
            'id': 'tax_${txId}_${tax.taxType}',
            'transaction_id': txId,
            'statement_id': statementId,
            'tax_type': tax.taxType,
            'amount_cents': tax.amountCents,
            'tax_date': record.date.toIso8601String().split('T')[0],
            'created_at': nowMs,
          });
        }
      }
    });

    if (targetWalletId != null) {
      try {
        await WalletRepository.instance.load();
        final wallet = WalletRepository.instance.wallets.firstWhere(
          (w) => w.id == targetWalletId,
          orElse: () => WalletRepository.instance.getConsolidatedWallet(),
        );
        int netChange = 0;
        if (wallet.type == WalletType.creditCard) {
          // Kredi kartı için harcamalar (debit) borcu artırır, ödemeler (credit) borcu azaltır
          netChange = result.totalDebitCents - result.totalCreditCents;
        } else {
          netChange = result.totalCreditCents - result.totalDebitCents;
        }
        await WalletRepository.instance.updateBalance(targetWalletId, wallet.balanceCents + netChange);
      } catch (_) {}
    }
  }

  /// Manuel Hızlı Giriş (Quick Entry) kaydı ekler.
  Future<void> saveManualTransaction({
    required String title,
    required int amountCents,
    required bool isExpense,
    required String categoryId,
    required DateTime date,
    String? note,
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
      'created_at': nowMs,
    });
  }

  /// Döneme ait toplam gider, toplam gelir ve net farkı hesaplar
  Future<Map<String, int>> getMonthlySummary({required String yearMonth}) async {
    final db = await _dbProvider.database;
    final res = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN transaction_type = 'DEBIT' THEN billing_amount_cents ELSE 0 END) as total_debit,
        SUM(CASE WHEN transaction_type = 'CREDIT' THEN billing_amount_cents ELSE 0 END) as total_credit
      FROM transactions
      WHERE transaction_date LIKE ?
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
  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 30, String? yearMonth}) async {
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
  Future<List<Map<String, dynamic>>> getUpcomingInstallments({int limit = 10}) async {
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
  Future<List<Map<String, dynamic>>> getCategorySpendingAnalysis({String? yearMonth}) async {
    final db = await _dbProvider.database;
    final whereClause = yearMonth != null && yearMonth.isNotEmpty
        ? "WHERE t.transaction_type = 'DEBIT' AND t.transaction_date LIKE ?"
        : "WHERE t.transaction_type = 'DEBIT'";
    final whereArgs = yearMonth != null && yearMonth.isNotEmpty ? ['$yearMonth%'] : [];

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
      WHERE transaction_type = 'DEBIT'
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

    const monthShortNames = ['OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', 'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA'];

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
    final deductibleCents = ((deductibleRow.firstOrNull?['total_cents'] as num?)?.toInt() ?? 0);

    return {
      'vat_cents': totalVatCents,
      'income_tax_cents': totalIncomeTaxCents,
      'sgk_cents': totalSgkCents,
      'other_tax_cents': totalOtherTaxCents,
      'deductible_cents': deductibleCents,
      'total_tax_cents': totalVatCents + totalIncomeTaxCents + totalSgkCents + totalOtherTaxCents,
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
          await txn.insert('accounts', a, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 2. Ekstreler
      final statements = data['statements'] as List<dynamic>? ?? [];
      for (final s in statements) {
        if (s is Map<String, dynamic>) {
          await txn.insert('statements', s, conflictAlgorithm: ConflictAlgorithm.replace);
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

          await txn.insert('transactions', cleanTx, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 4. Taksitler
      final installments = data['installments'] as List<dynamic>? ?? [];
      for (final i in installments) {
        if (i is Map<String, dynamic>) {
          await txn.insert('installments', i, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // 5. Vergiler
      final taxes = data['tax_deductions'] as List<dynamic>? ?? [];
      for (final tax in taxes) {
        if (tax is Map<String, dynamic>) {
          await txn.insert('tax_deductions', tax, conflictAlgorithm: ConflictAlgorithm.replace);
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
