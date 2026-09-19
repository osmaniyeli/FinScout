// DOSYA ADI: 12_REPO_transaction_repository.dart
// HEDEF DİZİN: lib/features/statement_parser/data/12_REPO_transaction_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../statement_parser/models/parsed_record.dart';

class TransactionRepository {
  final Database db;

  TransactionRepository(this.db);

  /// Ayrıştırılan bir ekstre veya bordroyu tüm alt tablolarıyla (kart, taksit, vergi)
  /// veri bütünlüğünü koruyarak tek bir işlem (transaction) içinde kaydeder.
  Future<void> saveParsedStatement({
    required String fileSha256,
    required String institutionName,
    required String accountType,
    required String periodStart,
    required String periodEnd,
    required List<ParsedRecord> records,
  }) async {
    await db.transaction((txn) async {
      // 1. Mükerrer Belge Kontrolü
      final existingStatement = await txn.query(
        'statements',
        where: 'file_sha256 = ?',
        whereArgs: [fileSha256],
      );
      if (existingStatement.isNotEmpty) {
        throw Exception('Bu ekstre daha önce sisteme yüklenmiş.');
      }

      final int now = DateTime.now().millisecondsSinceEpoch;
      final String statementId = 'stmt_${DateTime.now().microsecondsSinceEpoch}';

      int totalDebit = 0;
      int totalCredit = 0;

      // 2. İşlemleri ve Bağlı Varlıkları Yaz
      for (final record in records) {
        if (record.type == ParsedTransactionType.debit) {
          totalDebit += record.billingAmountCents;
        } else {
          totalCredit += record.billingAmountCents;
        }

        // Hesap Varlığı Oluştur veya Güncelle
        final String accountId = 'acc_${record.cardOrAccountMask.replaceAll(RegExp(r'\s+'), '_')}';
        await txn.rawInsert('''
          INSERT OR IGNORE INTO accounts (
            id, institution_name, account_type, account_name, 
            card_mask, card_holder, currency_code, created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          accountId,
          institutionName,
          accountType,
          '$institutionName ${record.cardOrAccountMask}',
          record.cardOrAccountMask,
          record.cardHolder ?? 'Kart Sahibi',
          record.billingCurrency,
          now,
        ]);

        // Kural Hafızasını Kontrol Et
        final rule = await txn.query(
          'user_category_rules',
          where: 'keyword_pattern = ?',
          whereArgs: [record.rawDescription],
        );
        final String finalCategory = rule.isNotEmpty
            ? rule.first['category_id'] as String
            : 'cat_general';

        final String txId = 'tx_${DateTime.now().microsecondsSinceEpoch}_${totalDebit + totalCredit}';

        // Harcama Satırını Ekle
        await txn.insert('transactions', {
          'id': txId,
          'account_id': accountId,
          'statement_id': statementId,
          'transaction_date': record.date.toIso8601String().split('T')[0],
          'transaction_type': record.type == ParsedTransactionType.debit ? 'DEBIT' : 'CREDIT',
          'raw_description': record.rawDescription,
          'clean_merchant': record.rawDescription,
          'category_id': finalCategory,
          'billing_amount_cents': record.billingAmountCents,
          'billing_currency': record.billingCurrency,
          'original_amount_cents': record.originalAmountCents,
          'original_currency': record.originalCurrency,
          'exchange_rate': record.exchangeRate,
          'is_installment': record.installment != null ? 1 : 0,
          'fast_or_tracking_id': record.fastOrTrackingId,
          'created_at': now,
        });

        // Taksit Varsa Kaydet
        if (record.installment != null) {
          final inst = record.installment!;
          await txn.insert('installments', {
            'id': 'inst_$txId',
            'transaction_id': txId,
            'current_installment': inst.currentInstallment,
            'total_installment': inst.totalInstallment,
            'monthly_amount_cents': inst.monthlyAmountCents,
            'remaining_amount_cents': inst.remainingAmountCents,
            'next_due_date': record.date.add(const Duration(days: 30)).toIso8601String().split('T')[0],
          });
        }

        // Vergi Kesintilerini Kaydet
        for (final tax in record.taxes) {
          await txn.insert('tax_deductions', {
            'id': 'tax_${DateTime.now().microsecondsSinceEpoch}',
            'transaction_id': txId,
            'statement_id': statementId,
            'tax_type': tax.taxType,
            'amount_cents': tax.amountCents,
            'tax_date': record.date.toIso8601String().split('T')[0],
          });
        }
      }

      // 3. Ekstre Ana Kaydını Tamamla
      await txn.insert('statements', {
        'id': statementId,
        'account_id': 'acc_${records.first.cardOrAccountMask.replaceAll(RegExp(r'\s+'), '_')}',
        'statement_type': accountType,
        'period_start': periodStart,
        'period_end': periodEnd,
        'total_debit_cents': totalDebit,
        'total_credit_cents': totalCredit,
        'file_sha256': fileSha256,
        'parsed_at': now,
      });

      // 4. Kota Sayacını Artır
      await txn.rawUpdate('''
        UPDATE app_meta 
        SET value = CAST(CAST(value AS INTEGER) + 1 AS TEXT) 
        WHERE key = 'current_month_pdf_count'
      ''');
    });
  }

  /// Kullanıcının sabitlediği satıcı kategori kuralını hafızaya alır.
  Future<void> saveMerchantRule(String rawPattern, String categoryId) async {
    await db.insert(
      'user_category_rules',
      {
        'id': 'rule_${DateTime.now().millisecondsSinceEpoch}',
        'keyword_pattern': rawPattern,
        'category_id': categoryId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Belirli bir ayın harcamalarını ve vergi detaylarını okur.
  Future<List<Map<String, dynamic>>> getTransactionsByPeriod(String yearMonth) async {
    return await db.rawQuery('''
      SELECT t.*, c.name as category_name, c.icon_name, c.color_hex
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.transaction_date LIKE ?
      ORDER BY t.transaction_date DESC
    ''', ['$yearMonth%']);
  }
}