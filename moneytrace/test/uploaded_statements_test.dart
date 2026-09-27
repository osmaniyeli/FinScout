// test/uploaded_statements_test.dart
//
// PROFİL EKRANI "Yüklediğim belgeler" alanı: TransactionRepository.getUploadedStatements()
// salt-okunur bir sorgu. Aynı test altyapısı (sqflite FFI + sahte path_provider) diğer repository
// testlerinde de (bkz. own_transfer_reconciliation_test.dart) kullanılıyor: AppDatabase'in gerçek
// şeması (assets/sql/*) ve TransactionRepository hiç değiştirilmeden, gerçek bir SQLite dosyasına
// karşı test eder.

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

/// Sentetik ekstre/bordro sonucu: gerçek PDF ayrıştırma zincirini atlayıp doğrudan
/// TransactionRepository.saveStatementResult'ı hedefler.
StatementDocumentResult _fakeStatement({
  required String institution,
  required String documentType,
  required String accountIdentifier,
  required DateTime periodStart,
  required DateTime periodEnd,
  required int recordCount,
}) {
  final records = List<ParsedRecord>.generate(
    recordCount,
    (i) => ParsedRecord(
      cardOrAccountMask: '',
      date: periodStart.add(Duration(days: i)),
      type: ParsedTransactionType.debit,
      rawDescription: 'MARKET ALISVERISI $i',
      billingAmountCents: 1000 + i,
      kind: TransactionKind.other,
    ),
  );
  return StatementDocumentResult(
    institution: institution,
    documentType: documentType,
    accountIdentifier: accountIdentifier,
    records: records,
    totalDebitCents: records.fold(0, (sum, r) => sum + r.billingAmountCents),
    totalCreditCents: 0,
    totalTaxCents: 0,
    periodStart: periodStart,
    periodEnd: periodEnd,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_uploaded_statements_test_');
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

  group('TransactionRepository.getUploadedStatements', () {
    test('hiç belge yüklenmediyse boş liste döner', () async {
      final repo = TransactionRepository();
      final result = await repo.getUploadedStatements();
      expect(result, isEmpty);
    });

    test('yüklenen belgeleri en yeni önce, doğru alanlarla döner', () async {
      final repo = TransactionRepository();

      await repo.saveStatementResult(
        result: _fakeStatement(
          institution: 'Yapı Kredi',
          documentType: 'CREDIT_CARD',
          accountIdentifier: 'TR000000000000000000001',
          periodStart: DateTime(2026, 1, 1),
          periodEnd: DateTime(2026, 1, 31),
          recordCount: 3,
        ),
        fileSha256: 'sha_1',
        fileName: 'yk_ocak.pdf',
      );

      // created_at milisaniye hassasiyetinde; ikinci kaydın "daha yeni" sayılması garanti olsun
      await Future.delayed(const Duration(milliseconds: 2));

      await repo.saveStatementResult(
        result: _fakeStatement(
          institution: 'Enpara',
          documentType: 'CHECKING',
          accountIdentifier: 'TR000000000000000000002',
          periodStart: DateTime(2026, 2, 1),
          periodEnd: DateTime(2026, 2, 28),
          recordCount: 5,
        ),
        fileSha256: 'sha_2',
        fileName: 'enpara_subat.pdf',
      );

      final result = await repo.getUploadedStatements();
      expect(result, hasLength(2));

      // En yeni önce: Enpara (ikinci yüklenen) ilk sırada
      final first = result[0];
      expect(first.institution, 'Enpara');
      expect(first.documentType, 'CHECKING');
      expect(first.fileName, 'enpara_subat.pdf');
      expect(first.fileSha256, 'sha_2');
      expect(first.transactionCount, 5);
      expect(first.periodStart, DateTime(2026, 2, 1));
      expect(first.periodEnd, DateTime(2026, 2, 28));

      final second = result[1];
      expect(second.institution, 'Yapı Kredi');
      expect(second.documentType, 'CREDIT_CARD');
      expect(second.fileName, 'yk_ocak.pdf');
      expect(second.transactionCount, 3);
    });

    test('bir belgeden gelen işlem sayısı yalnız o belgeye ait işlemleri sayar', () async {
      final repo = TransactionRepository();

      await repo.saveStatementResult(
        result: _fakeStatement(
          institution: 'Garanti',
          documentType: 'CREDIT_CARD',
          accountIdentifier: 'ACC_A',
          periodStart: DateTime(2026, 3, 1),
          periodEnd: DateTime(2026, 3, 31),
          recordCount: 2,
        ),
        fileSha256: 'sha_a',
        fileName: 'garanti_mart.pdf',
      );
      await repo.saveStatementResult(
        result: _fakeStatement(
          institution: 'Garanti',
          documentType: 'CREDIT_CARD',
          accountIdentifier: 'ACC_A',
          periodStart: DateTime(2026, 4, 1),
          periodEnd: DateTime(2026, 4, 30),
          recordCount: 7,
        ),
        fileSha256: 'sha_b',
        fileName: 'garanti_nisan.pdf',
      );

      final result = await repo.getUploadedStatements();
      expect(result, hasLength(2));
      expect(result.firstWhere((s) => s.fileName == 'garanti_mart.pdf').transactionCount, 2);
      expect(result.firstWhere((s) => s.fileName == 'garanti_nisan.pdf').transactionCount, 7);
    });

    test('dosya adı verilmezse varsayılan ad kullanılır', () async {
      final repo = TransactionRepository();
      await repo.saveStatementResult(
        result: _fakeStatement(
          institution: 'Akbank',
          documentType: 'PAYSLIP',
          accountIdentifier: '',
          periodStart: DateTime(2026, 5, 1),
          periodEnd: DateTime(2026, 5, 31),
          recordCount: 1,
        ),
        fileSha256: 'sha_payslip',
        // fileName verilmedi
      );

      final result = await repo.getUploadedStatements();
      expect(result.single.fileName, 'ekstre.pdf');
      expect(result.single.documentType, 'PAYSLIP');
    });
  });
}
