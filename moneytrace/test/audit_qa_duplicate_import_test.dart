// test/audit_qa_duplicate_import_test.dart
//
// DENETİM (QA 3/5) — Mükerrer içe aktarım. Üç katmanlı koruma (statement_upload_sheet.dart):
//   1) aynı dosya (SHA-256)            → TransactionRepository.isStatementAlreadyImported
//   2) aynı hesabın aynı dönemi         → isSamePeriodAlreadyImported (kesim tarihi, yoksa dönem)
//   3) işlem bazlı parmak izi           → saveStatementResult (fingerprint UNIQUE, ConflictAlgorithm.ignore)
// En gerçekçi risk (3): vadesiz hesap ekstreleri farklı ama ÇAKIŞAN tarih aralıklarıyla indirilir
// (1–31 Ağustos ve 15 Ağustos–15 Eylül). Çakışan işlemler ikinci kez yazılırsa gider/gelir şişer.
// Gerçek SQLite (sqflite FFI) + sahte path_provider; tutarlar uydurmadır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moneytrace/core/database/app_database.dart';
import 'package:moneytrace/core/database/repositories/transaction_repository.dart';
import 'package:moneytrace/core/parser/models/parsed_models.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

ParsedRecord _rec(DateTime d, int cents, String desc, {bool debit = true}) =>
    ParsedRecord(
      cardOrAccountMask: '',
      date: d,
      type: debit ? ParsedTransactionType.debit : ParsedTransactionType.credit,
      rawDescription: desc,
      cleanMerchant: desc,
      categoryId: 'cat_transit',
      billingAmountCents: cents,
      kind: TransactionKind.purchase,
    );

StatementDocumentResult _checking(
  List<ParsedRecord> records, {
  required DateTime start,
  required DateTime end,
  String id = 'TR00 1111',
  String institution = 'Yapı Kredi',
  String type = 'CHECKING',
  StatementSummary summary = StatementSummary.empty,
}) =>
    StatementDocumentResult(
      institution: institution,
      documentType: type,
      accountIdentifier: id,
      records: records,
      totalDebitCents: records
          .where((r) => r.type == ParsedTransactionType.debit)
          .fold(0, (a, r) => a + r.billingAmountCents),
      totalCreditCents: records
          .where((r) => r.type == ParsedTransactionType.credit)
          .fold(0, (a, r) => a + r.billingAmountCents),
      totalTaxCents: 0,
      periodStart: start,
      periodEnd: end,
      summary: summary,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late TransactionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_audit_dup_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    repo = TransactionRepository();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test(
      'çakışan dönemli iki vadesiz ekstre: çakışan işlemler bir kez sayılır, yeni olanlar eklenir',
      () async {
    final aug = _checking([
      _rec(DateTime(2026, 8, 3), 125000, 'MARKET A'),
      _rec(DateTime(2026, 8, 20), 1750, 'METRO GECIS'),
      _rec(DateTime(2026, 8, 20), 1750,
          'METRO GECIS'), // aynı gün meşru ikinci geçiş
      _rec(DateTime(2026, 8, 25), 50000, 'FATURA'),
    ], start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31));
    final overlap = _checking([
      _rec(DateTime(2026, 8, 20), 1750, 'METRO GECIS'),
      _rec(DateTime(2026, 8, 20), 1750,
          'METRO  gecis'), // boşluk/harf farkı: aynı işlem
      _rec(DateTime(2026, 8, 20), 1750, 'METRO GECIS'), // ÜÇÜNCÜ geçiş: yeni
      _rec(DateTime(2026, 8, 25), 50000, 'FATURA'),
      _rec(DateTime(2026, 9, 2), 9900, 'EYLUL ABONELIK'),
    ], start: DateTime(2026, 8, 15), end: DateTime(2026, 9, 15));

    final r1 =
        await repo.saveStatementResult(result: aug, fileSha256: 'sha_aug');
    expect(r1.inserted, 4);
    expect(await repo.isSamePeriodAlreadyImported(overlap), isFalse,
        reason:
            'Farklı dönem: dönem kontrolü durdurmamalı, işlem bazlı koruma devreye girmeli');
    final r2 = await repo.saveStatementResult(
        result: overlap, fileSha256: 'sha_overlap');
    expect(r2.skippedDuplicates, 3);
    expect(r2.inserted, 2);

    final aug26 = await repo.getMonthlySummary(yearMonth: '2026-08');
    expect(aug26['totalDebitCents'], 125000 + 3 * 1750 + 50000);
    final sep26 = await repo.getMonthlySummary(yearMonth: '2026-09');
    expect(sep26['totalDebitCents'], 9900);
  });

  test(
      'aynı dosya (SHA-256) ve aynı dönem (yeniden indirilmiş, kesim tarihli kart ekstresi) tespit edilir',
      () async {
    final card = _checking(
      [_rec(DateTime(2026, 8, 5), 30000, 'ONLINE')],
      start: DateTime(2026, 7, 20),
      end: DateTime(2026, 8, 19),
      id: '4462 12** **** 8281',
      type: 'CREDIT_CARD',
      summary: StatementSummary(
          statementDate: DateTime(2026, 8, 19), dueDate: DateTime(2026, 8, 29)),
    );
    expect(await repo.isStatementAlreadyImported('sha_x'), isFalse);
    await repo.saveStatementResult(result: card, fileSha256: 'sha_x');
    expect(await repo.isStatementAlreadyImported('sha_x'), isTrue);

    // Aynı kart, kart maskesi boşluksuz yazılmış (aynı hesap kimliğine çözülmeli), aynı kesim tarihi
    final redownload = _checking(
      [_rec(DateTime(2026, 8, 5), 30000, 'ONLINE')],
      start: DateTime(2026, 7,
          21), // dönem başı farklı okunsa bile kesim tarihi belirleyici
      end: DateTime(2026, 8, 19),
      id: '446212******8281',
      type: 'CREDIT_CARD',
      summary: StatementSummary(statementDate: DateTime(2026, 8, 19)),
    );
    expect(await repo.isSamePeriodAlreadyImported(redownload), isTrue);

    // Aynı bankanın BAŞKA kartı, aynı kesim tarihi: mükerrer DEĞİL
    final otherCard = _checking([_rec(DateTime(2026, 8, 5), 30000, 'ONLINE')],
        start: DateTime(2026, 7, 20),
        end: DateTime(2026, 8, 19),
        id: '5555 66** **** 7777',
        type: 'CREDIT_CARD',
        summary: StatementSummary(statementDate: DateTime(2026, 8, 19)));
    expect(await repo.isSamePeriodAlreadyImported(otherCard), isFalse);
  });

  test(
      'kesim tarihi okunamayan belgede dönem başı+sonu eşleşmesi mükerrer sayılır',
      () async {
    final a = _checking([_rec(DateTime(2026, 8, 3), 100, 'X')],
        start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31));
    await repo.saveStatementResult(result: a, fileSha256: 'sha_a');
    final b = _checking([_rec(DateTime(2026, 8, 4), 200, 'Y')],
        start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31));
    expect(await repo.isSamePeriodAlreadyImported(b), isTrue);
    final c = _checking([_rec(DateTime(2026, 8, 4), 200, 'Y')],
        start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 30));
    expect(await repo.isSamePeriodAlreadyImported(c), isFalse);
  });

  test(
      'aynı dosya SHA-256 ile ikinci kez kaydedilemez (UNIQUE) — koruma veritabanı düzeyinde de var',
      () async {
    final a = _checking([_rec(DateTime(2026, 8, 3), 100, 'X')],
        start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31));
    await repo.saveStatementResult(result: a, fileSha256: 'sha_same');
    await Future<void>.delayed(
        const Duration(milliseconds: 5)); // statement id (stmt_<ms>) çakışmasın
    await expectLater(
        repo.saveStatementResult(result: a, fileSha256: 'sha_same'),
        throwsA(anything));
    final s = await repo.getMonthlySummary(yearMonth: '2026-08');
    expect(s['totalDebitCents'], 100,
        reason:
            'Başarısız ikinci kayıt kısmi veri bırakmamalı (transaction geri alınır)');
  });

  test(
    'tamamı mükerrer bir ekstre kaydı (UI korumasını aşarsa) yaklaşan ödemeleri ÇİFTLEMEMELİ',
    () async {
      final due = DateTime.now().add(const Duration(days: 10));
      StatementDocumentResult card(String sha) => _checking(
            [
              _rec(DateTime.now().subtract(const Duration(days: 10)), 30000,
                  'ONLINE')
            ],
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now().subtract(const Duration(days: 1)),
            id: '4462',
            type: 'CREDIT_CARD',
            summary: StatementSummary(
              dueDate: due,
              statementBalanceCents: 30000,
              scheduledPayments: [
                ScheduledPayment(
                    date: due, description: 'OTOMATIK ODEME', amountCents: 9900)
              ],
            ),
          );
      await repo.saveStatementResult(
          result: card('sha_1'), fileSha256: 'sha_1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await repo.saveStatementResult(
          result: card('sha_2'), fileSha256: 'sha_2');
      expect(second.inserted, 0);
      final upcoming = await repo.getUpcomingPayments();
      expect(upcoming.where((p) => p['kind'] == 'CARD_DUE'), hasLength(1));
      expect(upcoming.where((p) => p['description'] == 'OTOMATIK ODEME'),
          hasLength(1));
    },
    skip:
        'BULGU QA-P3-04: saveStatementResult tüm işlemler mükerrer çıksa da (inserted=0) yeni bir statements '
        'satırı ve scheduled_payments satırları yazıyor; getUpcomingPayments aynı kart borcunu ve talimatı iki kez '
        'listeler, hatırlatma/"Yaklaşan" ekranı çiftlenir. Bugün statement_upload_sheet\'teki aynı-dönem kontrolü '
        'bunu önlüyor (savunma derinliği eksik): kesim tarihi bir ekstrede okunup diğerinde okunamazsa kontrol aşılır.',
  );
}
