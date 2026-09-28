// test/credit_card_payment_flow_test.dart
//
// [A3] "Borç Ödemesini Tamamla" (kredi kartı borcu ödeme) — 24 Eylül gece denetiminde bu akışın
// var olmayan bir kategoriye ('borc_odeme') yazmaya çalıştığı, FK hatasının try/catch ile yutulduğu
// ve hiç kayıt oluşmadan kullanıcıya "ödeme yapıldı" dendiği tespit edilmişti.
//
// K6 kararıyla ekran "Ödemeyi kaydet" olarak yeniden yazıldı (bkz. credit_card_action_sheet.dart,
// card_payment_flow.dart): artık gerçek bir kategoriye ('cat_card_payment') ve nötr bir tx_kind'e
// ('CARDPAYMENT') yazıyor. wallet_card_payments_test.dart yalnız saf allocateCardPayments
// fonksiyonunu test ediyor; BU dosya, gerçek bir SQLite'a karşı CardPaymentFlow.record'ın (ve
// dolayısıyla TransactionRepository.saveManualTransaction'ın) uçtan uca doğru satırı yazdığını,
// FK hatası vermediğini ve DB'den okununca doğru göründüğünü doğrular.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moneytrace/core/database/app_database.dart';
import 'package:moneytrace/core/database/repositories/transaction_repository.dart';
import 'package:moneytrace/features/assets_portfolio/presentation/widgets/card_payment_flow.dart';
import 'package:moneytrace/features/assets_portfolio/presentation/widgets/credit_card_action_sheet.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_cardpayment_test_');
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

  test('CardPaymentFlow.record: gerçek bir transactions satırı oluşturur (cat_card_payment / CARDPAYMENT)',
      () async {
    final repo = TransactionRepository();
    final card = {'bank': 'Yapı Kredi', 'name': 'Yapı Kredi'};
    const source = PaymentSource(accountId: null, label: 'Nakit Cüzdan');

    // FK hatası fırlatırsa test doğrudan başarısız olur (eski davranışta hata try/catch ile
    // yutulup hiçbir şey yazılmıyordu).
    await CardPaymentFlow.record(repo, card, 150000, source, DateTime(2026, 9, 15));

    final db = await AppDatabase.instance.database;
    final rows = await db.query('transactions', where: "tx_kind = 'CARDPAYMENT'");

    expect(rows.length, 1, reason: 'Ödeme tam olarak bir işlem satırı oluşturmalı');
    final row = rows.single;
    expect(row['category_id'], 'cat_card_payment');
    expect(row['billing_amount_cents'], 150000);
    expect(row['transaction_type'], 'DEBIT');

    // Kategori gerçekten var olmalı (FK'nin sessizce yutulmadığının kanıtı).
    final cat = await db.query('categories', where: 'id = ?', whereArgs: ['cat_card_payment']);
    expect(cat, isNotEmpty);
  });

  test('CARDPAYMENT nötr sayılır: aylık gelir/gider özetine girmez', () async {
    final repo = TransactionRepository();
    const source = PaymentSource(accountId: null, label: 'Nakit Cüzdan');
    await CardPaymentFlow.record(
        repo, {'bank': 'Yapı Kredi'}, 75000, source, DateTime(2026, 9, 15));

    final summary = await repo.getMonthlySummary(yearMonth: '2026-09');
    expect(summary['totalDebitCents'], 0,
        reason: 'Kart ödemesi CARDPAYMENT olarak nötrdür; gider sayılmamalı');
  });
}
