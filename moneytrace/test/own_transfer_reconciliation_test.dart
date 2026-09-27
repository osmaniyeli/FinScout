// test/own_transfer_reconciliation_test.dart
//
// KRİTİK DOĞRULUK HATASI: Kullanıcının kendi Yapı Kredi hesabından kendi Enpara hesabına yaptığı
// transfer, YK'de gider yazılıyor; parayı Enpara'dan harcayınca orada da gider yazılıyor — aynı para
// iki kez gider sayılıyor. Kök neden: kendi-transfer tespiti (StatementOrchestrator._enrich) yalnız TEK
// belge içinde isim eşleşmesiyle çalışıyordu; accountHolder'ı YK'nin genel okuyucusu hiç doldurmuyor.
//
// Bu testler, HESAPLAR ARASI TUTAR+TARİH eşleştirmesine dayanan yeni katmanı
// (TransactionRepository.reconcileOwnTransfers / saveStatementResult içindeki otomatik çağrı) doğrular.
// flutter_test VM'de gerçek platform kanalı olmadığından sqflite burada FFI (masaüstü sqlite3) ile,
// path_provider ise sahte bir PathProviderPlatform ile (her testte ayrı geçici klasör) çalıştırılır —
// böylece AppDatabase'in gerçek şeması (assets/sql/*) ve TransactionRepository hiç değiştirilmeden,
// gerçek bir SQLite dosyasına karşı uçtan uca test edilir.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moneytrace/core/database/app_database.dart';
import 'package:moneytrace/core/database/repositories/transaction_repository.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';

/// path_provider'ı gerçek platform kanalı olmadan, her testte ayrı bir geçici klasöre yönlendirir.
/// PathProviderPlatform'u `extends` etmek (implement değil) doğru token zincirini kurar; bu yüzden
/// plugin_platform_interface doğrulaması ek bir mixin gerektirmeden geçer.
class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Tek kayıtlı bir ekstre sonucu: gerçek PDF ayrıştırma zincirini atlayıp doğrudan
/// TransactionRepository.saveStatementResult'ı hedefleyen sentetik girdi üretir.
StatementDocumentResult _singleRecordStatement({
  required String institution,
  required String accountIdentifier,
  required DateTime date,
  required int amountCents,
  required ParsedTransactionType type,
  required TransactionKind kind,
  String? description,
}) {
  final record = ParsedRecord(
    cardOrAccountMask: '',
    date: date,
    type: type,
    rawDescription: description ??
        (type == ParsedTransactionType.debit ? 'FAST GIDEN AHMET YILMAZ' : 'FAST GELEN AHMET YILMAZ'),
    billingAmountCents: amountCents,
    kind: kind,
  );
  return StatementDocumentResult(
    institution: institution,
    documentType: 'CHECKING',
    accountIdentifier: accountIdentifier,
    records: [record],
    totalDebitCents: type == ParsedTransactionType.debit ? amountCents : 0,
    totalCreditCents: type == ParsedTransactionType.credit ? amountCents : 0,
    totalTaxCents: 0,
    periodStart: date,
    periodEnd: date,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_owntransfer_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
    }
  });

  /// Tüm işlemleri (hesap kimliğiyle) okur; kontrolleri kolaylaştırır.
  Future<List<Map<String, Object?>>> allTx() async {
    final db = await AppDatabase.instance.database;
    return db.query('transactions', columns: ['id', 'account_id', 'tx_kind', 'transaction_type', 'billing_amount_cents', 'transaction_date']);
  }

  /// "Bu düzeltmeden ÖNCE" yüklenmiş gibi, saveStatementResult'ı (ve dolayısıyla otomatik
  /// eşleştirmeyi) atlayarak doğrudan veritabanına ham bir işlem satırı ekler.
  Future<void> insertRawHistoricalTransaction({
    required String accountId,
    required String txId,
    required String date,
    required int amountCents,
    required String type, // 'DEBIT' | 'CREDIT'
    required String kind, // tx_kind
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('accounts', {
      'id': accountId,
      'institution_name': accountId,
      'account_type': 'CHECKING',
      'account_name': '$accountId Hesabı',
      'card_mask': '',
      'currency_code': 'TRY',
      'created_at': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('transactions', {
      'id': txId,
      'account_id': accountId,
      'transaction_date': date,
      'transaction_type': type,
      'raw_description': 'ESKI KAYIT $txId',
      'clean_merchant': 'ESKI KAYIT',
      'category_id': 'cat_general',
      'billing_amount_cents': amountCents,
      'billing_currency': 'TRY',
      'is_recurring': 0,
      'is_tax_deductible': 0,
      'tx_kind': kind,
      'created_at': 0,
    });
  }

  group('reconcileOwnTransfers (hesaplar arası tutar+tarih eşleştirmesi)', () {
    test(
        'aynı tutarlı transferOut (Hesap A) + transferIn (Hesap B, farklı hesap, 2 gün sonra) → '
        'ikisi de OWNTRANSFER olur (ikinci kayıt ilkini geriye dönük düzeltir)', () async {
      final repo = TransactionRepository();

      final outResult = _singleRecordStatement(
        institution: 'Yapı Kredi',
        accountIdentifier: 'TR000000000000000000001',
        date: DateTime(2026, 1, 10),
        amountCents: 500000,
        type: ParsedTransactionType.debit,
        kind: TransactionKind.transferOut,
      );
      final saveOut = await repo.saveStatementResult(result: outResult, fileSha256: 'sha_out_1');
      expect(saveOut.inserted, 1);

      // Bu noktada henüz ikinci hesap yok: tek kayıt TRANSFEROUT olarak kalmalı (normal davranış).
      final afterFirst = await allTx();
      expect(afterFirst, hasLength(1));
      expect(afterFirst.single['tx_kind'], 'TRANSFEROUT');

      final inResult = _singleRecordStatement(
        institution: 'Enpara',
        accountIdentifier: 'TR000000000000000000002',
        date: DateTime(2026, 1, 12),
        amountCents: 500000,
        type: ParsedTransactionType.credit,
        kind: TransactionKind.transferIn,
      );
      final saveIn = await repo.saveStatementResult(result: inResult, fileSha256: 'sha_in_1');
      expect(saveIn.inserted, 1);

      final rows = await allTx();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r['tx_kind'] == 'OWNTRANSFER'), isTrue,
          reason: 'İki ayrı hesaptaki ters yönlü, aynı tutarlı, yakın tarihli transferler eşleşmeli');

      // Gelir/gider toplamlarına girmemeli (neutralKindsSql = OWNTRANSFER hariç tutuyor)
      final summary = await repo.getMonthlySummary(yearMonth: '2026-01');
      expect(summary['totalDebitCents'], 0);
      expect(summary['totalCreditCents'], 0);
    });

    test('tutar 1 kuruş bile farklıysa EŞLEŞMEZ', () async {
      final repo = TransactionRepository();
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Yapı Kredi',
          accountIdentifier: 'ACC_A',
          date: DateTime(2026, 2, 1),
          amountCents: 300000,
          type: ParsedTransactionType.debit,
          kind: TransactionKind.transferOut,
        ),
        fileSha256: 'sha_a',
      );
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Enpara',
          accountIdentifier: 'ACC_B',
          date: DateTime(2026, 2, 1),
          amountCents: 300001, // 1 kuruş fark
          type: ParsedTransactionType.credit,
          kind: TransactionKind.transferIn,
        ),
        fileSha256: 'sha_b',
      );

      final rows = await allTx();
      expect(rows, hasLength(2));
      expect(rows.any((r) => r['tx_kind'] == 'TRANSFEROUT'), isTrue);
      expect(rows.any((r) => r['tx_kind'] == 'TRANSFERIN'), isTrue);
      expect(rows.any((r) => r['tx_kind'] == 'OWNTRANSFER'), isFalse);
    });

    test('4 gün arayla olan aynı tutarlı transfer EŞLEŞMEZ (±3 gün sınırı)', () async {
      final repo = TransactionRepository();
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Yapı Kredi',
          accountIdentifier: 'ACC_A',
          date: DateTime(2026, 3, 1),
          amountCents: 250000,
          type: ParsedTransactionType.debit,
          kind: TransactionKind.transferOut,
        ),
        fileSha256: 'sha_a2',
      );
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Enpara',
          accountIdentifier: 'ACC_B',
          date: DateTime(2026, 3, 5), // 4 gün sonra
          amountCents: 250000,
          type: ParsedTransactionType.credit,
          kind: TransactionKind.transferIn,
        ),
        fileSha256: 'sha_b2',
      );

      final rows = await allTx();
      expect(rows.any((r) => r['tx_kind'] == 'OWNTRANSFER'), isFalse);
    });

    test('tam sınırda (3 gün) EŞLEŞİR', () async {
      final repo = TransactionRepository();
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Yapı Kredi',
          accountIdentifier: 'ACC_A',
          date: DateTime(2026, 3, 1),
          amountCents: 250000,
          type: ParsedTransactionType.debit,
          kind: TransactionKind.transferOut,
        ),
        fileSha256: 'sha_a3',
      );
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Enpara',
          accountIdentifier: 'ACC_B',
          date: DateTime(2026, 3, 4), // tam 3 gün sonra
          amountCents: 250000,
          type: ParsedTransactionType.credit,
          kind: TransactionKind.transferIn,
        ),
        fileSha256: 'sha_b3',
      );

      final rows = await allTx();
      expect(rows.every((r) => r['tx_kind'] == 'OWNTRANSFER'), isTrue);
    });

    test('aynı hesap içindeki transferOut+transferIn eşleşmemeli (farklı account_id şartı)', () async {
      final repo = TransactionRepository();
      // Aynı kurum + aynı hesap kimliği → accountIdFor aynı account_id üretir.
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Yapı Kredi',
          accountIdentifier: 'ACC_SAME',
          date: DateTime(2026, 4, 1),
          amountCents: 100000,
          type: ParsedTransactionType.debit,
          kind: TransactionKind.transferOut,
        ),
        fileSha256: 'sha_same_1',
      );
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Yapı Kredi',
          accountIdentifier: 'ACC_SAME',
          date: DateTime(2026, 4, 2),
          amountCents: 100000,
          type: ParsedTransactionType.credit,
          kind: TransactionKind.transferIn,
        ),
        fileSha256: 'sha_same_2',
      );

      final rows = await allTx();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r['account_id'] == rows.first['account_id']), isTrue);
      expect(rows.any((r) => r['tx_kind'] == 'OWNTRANSFER'), isFalse);
    });

    test('zaten CARDPAYMENT/OWNTRANSFER olan kayıtlar tekrar işlenmez', () async {
      final repo = TransactionRepository();
      // Kart borcu ödemesi (nötr, zaten CARDPAYMENT) — TRANSFEROUT değil, hiç aday olmamalı.
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Yapı Kredi',
          accountIdentifier: 'ACC_CARD_PAY',
          date: DateTime(2026, 5, 1),
          amountCents: 400000,
          type: ParsedTransactionType.debit,
          kind: TransactionKind.cardPayment,
        ),
        fileSha256: 'sha_cardpay',
      );
      // Aynı tutar/tarihli bir TRANSFERIN farklı hesapta olsa bile CARDPAYMENT ile eşleşmemeli.
      await repo.saveStatementResult(
        result: _singleRecordStatement(
          institution: 'Enpara',
          accountIdentifier: 'ACC_CARD_PAY_2',
          date: DateTime(2026, 5, 1),
          amountCents: 400000,
          type: ParsedTransactionType.credit,
          kind: TransactionKind.transferIn,
        ),
        fileSha256: 'sha_cardpay_in',
      );

      final rows = await allTx();
      expect(rows.firstWhere((r) => r['tx_kind'] == 'CARDPAYMENT' || r['transaction_type'] == 'DEBIT')['tx_kind'],
          'CARDPAYMENT');
      // TRANSFERIN eşleşecek bir TRANSFEROUT bulunmadığından TRANSFERIN olarak kalmalı.
      expect(rows.any((r) => r['tx_kind'] == 'TRANSFERIN'), isTrue);
      expect(rows.any((r) => r['tx_kind'] == 'OWNTRANSFER'), isFalse);
    });

    test('reconcileOwnTransfers() bağımsız çağrıldığında (main.dart açılışını taklit ederek) '
        'eşleşmemiş eski kayıtları düzeltir', () async {
      // saveStatementResult'ı atlayıp doğrudan veritabanına, DÜZELTMEDEN ÖNCE yüklenmiş gibi
      // eşleşmemiş TRANSFEROUT/TRANSFERIN çifti ekle.
      await insertRawHistoricalTransaction(
        accountId: 'acc_old_yk',
        txId: 'tx_old_out',
        date: '2025-06-01',
        amountCents: 750000,
        type: 'DEBIT',
        kind: 'TRANSFEROUT',
      );
      await insertRawHistoricalTransaction(
        accountId: 'acc_old_enpara',
        txId: 'tx_old_in',
        date: '2025-06-02',
        amountCents: 750000,
        type: 'CREDIT',
        kind: 'TRANSFERIN',
      );

      final before = await allTx();
      expect(before.every((r) => r['tx_kind'] != 'OWNTRANSFER'), isTrue);

      final repo = TransactionRepository();
      final pairs = await repo.reconcileOwnTransfers();
      expect(pairs, 1);

      final after = await allTx();
      expect(after.every((r) => r['tx_kind'] == 'OWNTRANSFER'), isTrue);
    });
  });
}
