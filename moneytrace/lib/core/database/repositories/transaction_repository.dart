import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../../services/data_changes.dart';
import '../../parser/models/parsed_models.dart';

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

  /// Ekstrenin kaydedileceği hesabın kimliği. Kart/hesap numarası okunamadıysa aynı bankanın kartı ile
  /// vadesizi tek hesapta birleşmesin diye belge türü kullanılır.
  static String accountIdFor(StatementDocumentResult result) {
    final bank = result.institution.toLowerCase().replaceAll(' ', '_');
    final identifier = result.accountIdentifier.replaceAll(' ', '');
    return identifier.isEmpty
        ? 'acc_${bank}_${result.documentType.toLowerCase()}'
        : 'acc_${bank}_$identifier';
  }

  /// Aynı-dönem kontrolü bu belgeye uygulanır mı? Bordroda uygulanmaz: aynı ay için eşin bordrosu
  /// (ya da fark bordrosu) meşru olarak eklenebilir; bordroda yalnız dosya birebir aynıysa
  /// (SHA-256, [isStatementAlreadyImported]) uyarı verilir. Kart/hesap ekstrelerinde aynen uygulanır.
  static bool samePeriodCheckApplies(StatementDocumentResult result) => result.documentType != 'PAYSLIP';

  /// Aynı hesabın aynı dönemi daha önce yüklendi mi? Bankadan yeniden indirilen ekstrenin dosya özeti
  /// (SHA-256) farklı olabilir; bu yüzden hesap + hesap kesim tarihi (yoksa dönem sonu) da karşılaştırılır.
  /// Bordrolar için her zaman false ([samePeriodCheckApplies]).
  Future<bool> isSamePeriodAlreadyImported(StatementDocumentResult result) async {
    if (!samePeriodCheckApplies(result)) return false;
    final db = await _dbProvider.database;
    String day(DateTime d) => d.toIso8601String().split('T')[0];
    final statementDay = result.summary.statementDate;
    final res = statementDay != null
        ? await db.query('statements',
            columns: ['id'],
            where: 'account_id = ? AND statement_date = ?',
            whereArgs: [accountIdFor(result), day(statementDay)],
            limit: 1)
        : await db.query('statements',
            columns: ['id'],
            where: 'account_id = ? AND period_start = ? AND period_end = ?',
            whereArgs: [accountIdFor(result), day(result.periodStart), day(result.periodEnd)],
            limit: 1);
    return res.isNotEmpty;
  }

  /// Gelir/gider analizlerine girmeyen işlem türleri: kart borcu ödemesi (harcama zaten kart ekstresinde
  /// sayıldı) ve kişinin kendi hesapları arası aktarımı. Aksi halde aynı para iki kez sayılır.
  static const String neutralKindsSql = "('CARDPAYMENT','OWNTRANSFER')";

  /// Bordrodaki net maaş, aynı maaşın vadesiz hesaba yatışı da yüklendiyse ikinci kez gelir sayılmaz.
  /// (Bordro ayın son günü tarihli; yatış ±20 gün içinde aranır.) `t` takma adıyla kullanılır.
  static const String payslipDuplicateFilterSql = """
    AND NOT (t.tx_kind = 'SALARY'
      AND t.account_id IN (SELECT id FROM accounts WHERE account_type = 'PAYSLIP')
      AND EXISTS (SELECT 1 FROM transactions s JOIN accounts sa ON sa.id = s.account_id
        WHERE s.tx_kind = 'SALARY' AND sa.account_type <> 'PAYSLIP'
          AND ABS(julianday(s.transaction_date) - julianday(t.transaction_date)) <= 20))
  """;

  /// İşlemin mükerrer parmak izi anahtarı (fingerprint = sha1(anahtar#tekrar)).
  /// Kart/hesap ekstresinde: hesap + tarih + tutar + açıklama + taksit no; aynı işlem farklı (yeniden
  /// indirilmiş) dosyadan tekrar gelirse atlanır. Bordroda dosya özeti (SHA-256) de anahtara girer:
  /// bordro tek kayıtlıdır ve aynı ay için eşin bordrosu aynı tutarda olsa bile farklı dosyadır,
  /// eklenebilmelidir. Birebir aynı bordro dosyası zaten SHA-256 kontrolüyle yüklemeden önce durur.
  static String transactionDedupKey({
    required StatementDocumentResult result,
    required String accountId,
    required String fileSha256,
    required ParsedRecord record,
  }) {
    String day(DateTime d) => d.toIso8601String().split('T')[0];
    return [
      accountId,
      day(record.date),
      record.signedAmountCents,
      record.rawDescription.toUpperCase().replaceAll(RegExp(r'\s+'), ' '),
      record.installment?.currentInstallment ?? 0,
      if (result.documentType == 'PAYSLIP') 'file:$fileSha256',
    ].join('|');
  }

  /// Parser çıktısını tek veritabanı transaction'ı içinde kaydeder.
  /// Aynı işlem (aynı hesap, tarih, tutar, açıklama) tekrar içe aktarılırsa atlanır
  /// (bordroda dosya bazında ayrılır, bkz. [transactionDedupKey]).
  Future<StatementSaveResult> saveStatementResult({
    required StatementDocumentResult result,
    required String fileSha256,
    String? fileName,
  }) async {
    final db = await _dbProvider.database;
    var inserted = 0;
    var skipped = 0;

    await db.transaction((txn) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      String day(DateTime d) => d.toIso8601String().split('T')[0];

      // 1. Hesap (Account) oluştur veya bul
      final accountId = accountIdFor(result);
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
        final baseKey = transactionDedupKey(
            result: result, accountId: accountId, fileSha256: fileSha256, record: record);
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
            // Bordro birim ücreti yalnız bordronun maaş kaydına yazılır (zam tespiti)
            if (result.documentType == 'PAYSLIP' && record.kind == TransactionKind.salary)
              'base_wage_cents': summary.payslipBaseWageCents,
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

    if (inserted > 0) DataChanges.notify();
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
    final changed = await db.update(
      'transactions',
      {'category_id': categoryId},
      where: 'UPPER(counterparty) = ? OR UPPER(clean_merchant) = ?',
      whereArgs: [pattern, pattern],
    );
    DataChanges.notify();
    return changed;
  }

  /// Yalnız tek bir işlemin kategorisini değiştirir (kural kaydetmez).
  Future<bool> updateTransactionCategory(String transactionId, String categoryId) async {
    final db = await _dbProvider.database;
    final changed = await db.update(
      'transactions',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    if (changed > 0) DataChanges.notify();
    return changed > 0;
  }

  /// Kategori seçici için tüm kategoriler (ada göre sıralı).
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await _dbProvider.database;
    return db.query('categories',
        columns: ['id', 'parent_id', 'name', 'icon_name', 'color_hex'],
        orderBy: 'name COLLATE NOCASE ASC');
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
    /// Verilirse işlem bu mevcut hesaba yazılır (ör. kart ödemesinin çıktığı vadesiz hesap); yoksa nakit cüzdan.
    String? accountId,
  }) async {
    final db = await _dbProvider.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final txId = 'manual_tx_$nowMs';
    final useCash = accountId == null;
    accountId ??= 'acc_manual_cash';

    if (useCash) {
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
    }

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
    DataChanges.notify();
  }

  /// Döneme ait toplam gider, toplam gelir ve net farkı hesaplar
  Future<Map<String, int>> getMonthlySummary(
      {required String yearMonth}) async {
    final db = await _dbProvider.database;
    // İade gelir değil, harcamayı azaltır.
    final res = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN t.transaction_type = 'DEBIT' THEN t.billing_amount_cents ELSE 0 END)
          - SUM(CASE WHEN t.transaction_type = 'CREDIT' AND t.tx_kind = 'REFUND' THEN t.billing_amount_cents ELSE 0 END) as total_debit,
        SUM(CASE WHEN t.transaction_type = 'CREDIT' AND t.tx_kind <> 'REFUND' THEN t.billing_amount_cents ELSE 0 END) as total_credit
      FROM transactions t
      WHERE t.transaction_date LIKE ? AND t.tx_kind NOT IN $neutralKindsSql $payslipDuplicateFilterSql
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
          t.category_id,
          t.counterparty,
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
        t.category_id,
        t.counterparty,
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

  /// Devam eden taksit planları. Her aylık ekstre aynı alışverişi yeni bir satır (2/6, 3/6…) olarak
  /// getirir; her plan için yalnız en güncel satır alınır. Son taksidi (n/n) görülen plan bitmiş sayılır.
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
        c.color_hex,
        a.institution_name
      FROM installments i
      JOIN transactions t ON i.transaction_id = t.id
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON a.id = t.account_id
      WHERE i.current_installment < i.total_installment
        AND i.id = (
          SELECT i2.id FROM installments i2 JOIN transactions t2 ON t2.id = i2.transaction_id
          WHERE t2.account_id = t.account_id
            AND UPPER(t2.clean_merchant) = UPPER(t.clean_merchant)
            AND i2.total_installment = i.total_installment
          ORDER BY i2.current_installment DESC, i2.created_at DESC LIMIT 1)
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
      FROM (
        -- İadeler o ayın harcamasından düşülür
        SELECT transaction_date,
               CASE WHEN transaction_type = 'DEBIT' THEN billing_amount_cents ELSE -billing_amount_cents END AS billing_amount_cents
        FROM transactions
        WHERE tx_kind NOT IN $neutralKindsSql
          AND (transaction_type = 'DEBIT' OR tx_kind = 'REFUND')
      )
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

    // Yedeğe ek tablolar: planlı ödemeler, kategori kuralları, hedefler ve katkıları
    final extras = <String, List<Map<String, dynamic>>>{
      for (final t in TransactionRepositoryBackup.extraTables) t: await db.query(t),
    };

    final transactionsWithDetails = await db.rawQuery('''
      SELECT 
        t.*,
        c.name as category_name,
        a.institution_name,
        a.card_mask,
        i.current_installment,
        i.total_installment,
        tax.tax_type,
        tax.tax_amount_cents
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN installments i ON i.transaction_id = t.id
      -- Bir işlemin birden çok vergi satırı (BSMV + KKDF) işlemi çoğaltmasın: tek satıra indir
      LEFT JOIN (
        SELECT transaction_id, GROUP_CONCAT(tax_type, ' + ') AS tax_type, SUM(amount_cents) AS tax_amount_cents
        FROM tax_deductions GROUP BY transaction_id
      ) tax ON tax.transaction_id = t.id
      ORDER BY t.transaction_date DESC, t.created_at DESC
    ''');

    return {
      'accounts': accounts,
      'statements': statements,
      'transactions': transactionsWithDetails,
      'installments': installments,
      'tax_deductions': taxes,
      ...extras,
    };
  }

  /// JSON yedeğini tek transaction içinde geri yükler. Önce mevcut kayıtlar silinir:
  /// yedek, telefondaki verinin üstüne birleştirilmez, onun yerine geçer.
  Future<void> restoreVaultBackup(Map<String, dynamic> data) async {
    final db = await _dbProvider.database;

    await db.transaction((txn) async {
      await _clearUserTables(txn);

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

      // 6. Ek tablolar (yedekte varsa yerine geçer; eski yedekte yoksa mevcut kayıtlar kalır)
      for (final table in TransactionRepositoryBackup.extraTables) {
        final rows = data[table];
        if (rows is! List) continue;
        if (table == 'goals') await txn.delete('goal_contributions');
        await txn.delete(table);
        for (final row in rows) {
          if (row is Map<String, dynamic>) {
            await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });
    DataChanges.notify();
  }

  /// Kullanıcı verilerini tamamen sıfırlar.
  Future<void> clearAllUserData() async {
    final db = await _dbProvider.database;
    await db.transaction(_clearUserTables);
    DataChanges.notify();
  }

  static Future<void> _clearUserTables(Transaction txn) async {
    await txn.delete('tax_deductions');
    await txn.delete('installments');
    await txn.delete('scheduled_payments');
    await txn.delete('transactions');
    await txn.delete('statements');
    await txn.delete('accounts');
  }

  /// Tek bir işlemi, bağlı taksit ve vergi satırlarıyla birlikte kalıcı olarak siler.
  Future<bool> deleteTransaction(String transactionId) async {
    final db = await _dbProvider.database;
    var deleted = 0;
    await db.transaction((txn) async {
      await txn.delete('tax_deductions', where: 'transaction_id = ?', whereArgs: [transactionId]);
      await txn.delete('installments', where: 'transaction_id = ?', whereArgs: [transactionId]);
      deleted = await txn.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
    });
    if (deleted > 0) DataChanges.notify();
    return deleted > 0;
  }

  /// Kayıtlı tüm hesapları ve kartları getirir
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await _dbProvider.database;
    return await db.query('accounts', orderBy: 'created_at DESC');
  }

  /// Ekstrelerden gelen hesaplar + her birinin EN SON ekstresindeki banka beyanları
  /// (dönem borcu, asgari, son ödeme, hesap kesim). Uydurma limit/borç yok; bilinmeyen alan null döner.
  Future<List<Map<String, dynamic>>> getAccountsWithLatestStatement() async {
    final db = await _dbProvider.database;
    return db.rawQuery('''
      SELECT a.id, a.institution_name, a.account_type, a.card_mask, a.card_holder,
             s.statement_balance_cents, s.minimum_payment_cents, s.due_date, s.statement_date, s.period_end
      FROM accounts a
      LEFT JOIN statements s ON s.id = (
        SELECT s2.id FROM statements s2 WHERE s2.account_id = a.id
        ORDER BY COALESCE(s2.statement_date, s2.period_end) DESC, s2.created_at DESC LIMIT 1
      )
      WHERE a.account_type IN ('CREDIT_CARD', 'CHECKING')
      ORDER BY a.created_at DESC
    ''');
  }

  /// Bordrodan gelen maaş kayıtları (net = billing, brüt = original; brüt okunamadıysa null;
  /// base_wage_cents = bordrodaki birim ücret, okunamadıysa null)
  /// ve bu kayıtlara bağlı yasal kesinti kalemleri. Hesaplama PayslipAnalyticsService'te yapılır.
  Future<({List<Map<String, Object?>> incomes, List<Map<String, Object?>> taxes})> getPayslipRows() async {
    final db = await _dbProvider.database;
    final incomes = await db.rawQuery('''
      SELECT t.id, t.transaction_date, t.billing_amount_cents, t.original_amount_cents, t.base_wage_cents
      FROM transactions t JOIN accounts a ON a.id = t.account_id
      WHERE a.account_type = 'PAYSLIP' AND t.tx_kind = 'SALARY' AND t.transaction_type = 'CREDIT'
      ORDER BY t.transaction_date
    ''');
    final taxes = await db.rawQuery('''
      SELECT d.transaction_id, t.transaction_date, d.tax_type, d.amount_cents
      FROM tax_deductions d
      JOIN transactions t ON t.id = d.transaction_id
      JOIN accounts a ON a.id = t.account_id
      WHERE a.account_type = 'PAYSLIP'
      ORDER BY t.transaction_date
    ''');
    return (incomes: incomes, taxes: taxes);
  }
}

class StatementSaveResult {
  final int inserted;
  final int skippedDuplicates;
  const StatementSaveResult({required this.inserted, required this.skippedDuplicates});
}

/// Yedekte işlem tablolarına ek olarak taşınan tablolar (sıra: yabancı anahtarlara göre).
class TransactionRepositoryBackup {
  static const extraTables = ['scheduled_payments', 'merchant_rules', 'goals', 'goal_contributions'];
}
