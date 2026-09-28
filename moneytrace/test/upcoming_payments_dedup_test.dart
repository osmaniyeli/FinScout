// test/upcoming_payments_dedup_test.dart
//
// [A1/#2] "Yaklaşan Taksitler & Borçlar" — 24 Eylül gece denetiminde, aynı kartın birden çok aylık
// ekstresi yüklendiğinde aynı taksitin farklı satırlar olarak tekrar ettiği ve kart ekstresi son
// ödeme borcunun (dönem borcunun tamamı) hiç gösterilmediği tespit edilmişti.
//
// Bu dosya, TransactionRepository.getUpcomingInstallments (dedup: her taksit planının yalnız en
// güncel satırı) ve TransactionRepository.getUpcomingPayments (CARD_DUE: kart ekstresi son ödeme
// borcu) davranışını gerçek bir SQLite'a karşı uçtan uca doğrular — aynı desende
// own_transfer_reconciliation_test.dart.

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

/// Aynı kartın bir aylık ekstresi: tek taksitli bir işlem + banka beyanı (dönem borcu/son ödeme).
StatementDocumentResult _cardStatement({
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime dueDate,
  required int currentInstallment,
  required int statementBalanceCents,
}) {
  final record = ParsedRecord(
    cardOrAccountMask: '1234',
    date: periodStart.add(const Duration(days: 2)),
    type: ParsedTransactionType.debit,
    rawDescription: 'ELEKTRONIK MARKETI TAKSIT $currentInstallment/12',
    cleanMerchant: 'Elektronik Marketi',
    billingAmountCents: 100000,
    installment: ParsedInstallmentData(
      currentInstallment: currentInstallment,
      totalInstallment: 12,
      remainingAmountCents: (12 - currentInstallment) * 100000,
      monthlyAmountCents: 100000,
    ),
  );
  return StatementDocumentResult(
    institution: 'Yapı Kredi',
    documentType: 'CREDIT_CARD',
    accountIdentifier: '1234',
    records: [record],
    totalDebitCents: 100000,
    totalCreditCents: 0,
    totalTaxCents: 0,
    periodStart: periodStart,
    periodEnd: periodEnd,
    summary: StatementSummary(
      dueDate: dueDate,
      statementBalanceCents: statementBalanceCents,
      minimumPaymentCents: (statementBalanceCents * 0.2).round(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_upcoming_test_');
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

  test('getUpcomingInstallments: aynı taksit planının iki aylık ekstresi tekrar etmez, en güncel satır kalır',
      () async {
    final repo = TransactionRepository();
    final now = DateTime.now();

    // Ay 1: 3/12 (geçmiş bir ekstre)
    await repo.saveStatementResult(
      result: _cardStatement(
        periodStart: DateTime(now.year, now.month - 2, 1),
        periodEnd: DateTime(now.year, now.month - 2, 28),
        dueDate: DateTime(now.year, now.month - 2, 30),
        currentInstallment: 3,
        statementBalanceCents: 500000,
      ),
      fileSha256: 'sha_ay1',
    );
    // Ay 2: 4/12 (daha güncel ekstre, aynı taksit planı)
    await repo.saveStatementResult(
      result: _cardStatement(
        periodStart: DateTime(now.year, now.month - 1, 1),
        periodEnd: DateTime(now.year, now.month - 1, 28),
        dueDate: DateTime(now.year, now.month - 1, 30),
        currentInstallment: 4,
        statementBalanceCents: 400000,
      ),
      fileSha256: 'sha_ay2',
    );

    final upcoming = await repo.getUpcomingInstallments();
    final thisPlan = upcoming
        .where((r) => r['clean_merchant'] == 'Elektronik Marketi')
        .toList();

    expect(thisPlan.length, 1,
        reason: 'Aynı taksit planı iki ekstrede de göründüğü için tek satıra inmeli (mükerrer olmamalı)');
    expect(thisPlan.single['current_installment'], 4,
        reason: 'En güncel (son ekstredeki) taksit numarası gösterilmeli');
  });

  test('getUpcomingInstallments: bitmiş taksit (n/n) artık listede görünmez', () async {
    final repo = TransactionRepository();
    final now = DateTime.now();
    await repo.saveStatementResult(
      result: _cardStatement(
        periodStart: DateTime(now.year, now.month - 1, 1),
        periodEnd: DateTime(now.year, now.month - 1, 28),
        dueDate: DateTime(now.year, now.month - 1, 30),
        currentInstallment: 12,
        statementBalanceCents: 100000,
      ),
      fileSha256: 'sha_son',
    );

    final upcoming = await repo.getUpcomingInstallments();
    expect(upcoming.where((r) => r['clean_merchant'] == 'Elektronik Marketi'), isEmpty,
        reason: '12/12 tamamlanmış taksit "kalan" listesinde sonsuza dek görünmemeli');
  });

  test('getUpcomingPayments: en güncel ekstrenin kart borcu (CARD_DUE) gelecekteki son ödeme tarihiyle listelenir',
      () async {
    final repo = TransactionRepository();
    final futureDue = DateTime.now().add(const Duration(days: 10));
    await repo.saveStatementResult(
      result: _cardStatement(
        periodStart: DateTime.now().subtract(const Duration(days: 20)),
        periodEnd: DateTime.now().subtract(const Duration(days: 5)),
        dueDate: futureDue,
        currentInstallment: 1,
        statementBalanceCents: 250000,
      ),
      fileSha256: 'sha_future',
    );

    final payments = await repo.getUpcomingPayments();
    final cardDue = payments.where((p) => p['kind'] == 'CARD_DUE').toList();

    expect(cardDue.length, 1);
    expect(cardDue.single['amount_cents'], 250000);
    expect((cardDue.single['description'] as String).contains('Yapı Kredi'), isTrue);
  });
}
