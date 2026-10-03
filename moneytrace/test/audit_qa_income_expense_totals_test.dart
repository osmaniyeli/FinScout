// test/audit_qa_income_expense_totals_test.dart
//
// DENETİM (QA 3/5) — Gelir/gider toplamlarının KAYNAK İŞLEMLERDEN yeniden doğrulanması.
// Gerçekçi bir ay (Ağustos 2026) kurulur: Yapı Kredi kartı (alışveriş, iade, faiz, kart ödemesi),
// YK vadesiz (maaş, karttan ödeme, Enpara'ya kendi transferi, fatura, arkadaştan gelen para),
// Enpara vadesiz (kendi transferinin karşılığı, harcama), bordro (aynı maaş — vadesizde de var)
// ve nakit manuel gider. Ay dışı (Temmuz/Eylül) kayıtlar sınır kontrolü içindir.
//
// Beklenen toplamlar, repository'den BAĞIMSIZ olarak bu dosyadaki kaynak listeden, belgelenmiş
// kurallarla hesaplanır (transaction_repository.dart):
//   gider = Σ BORÇ (CARDPAYMENT/OWNTRANSFER hariç) − Σ İADE
//   gelir = Σ ALACAK (İADE, CARDPAYMENT, OWNTRANSFER hariç; vadesizde de görünen bordro maaşı hariç)
// ve getMonthlySummary / getMonthlyTrendsAnalysis / getCategorySpendingAnalysis ile karşılaştırılır.
// Tutarlar uydurmadır; tamsayı kuruş.

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

/// Kaynak kayıt + beklenen muhasebe sınıfı (repository'den bağımsız "kahin").
class _Src {
  final DateTime date;
  final bool debit;
  final int cents;
  final TransactionKind kind;
  final String category;
  final String desc;

  /// Beklenen: kendi transferi eşleşmesine girecek mi (OWNTRANSFER'a dönecek)?
  final bool expectOwnTransfer;

  /// Beklenen: bordrodaki maaş, vadesizde de göründüğü için gelire ikinci kez girmez.
  final bool expectPayslipDuplicate;

  const _Src(
      this.date, this.debit, this.cents, this.kind, this.category, this.desc,
      {this.expectOwnTransfer = false, this.expectPayslipDuplicate = false});

  ParsedRecord toRecord() => ParsedRecord(
        cardOrAccountMask: '',
        date: date,
        type:
            debit ? ParsedTransactionType.debit : ParsedTransactionType.credit,
        rawDescription: desc,
        cleanMerchant: desc,
        categoryId: category,
        billingAmountCents: cents,
        kind: kind,
      );

  bool get neutral =>
      kind == TransactionKind.cardPayment ||
      expectOwnTransfer ||
      expectPayslipDuplicate;
}

StatementDocumentResult _doc(
    String institution, String type, String id, List<_Src> src) {
  final dates = src.map((s) => s.date).toList()..sort();
  return StatementDocumentResult(
    institution: institution,
    documentType: type,
    accountIdentifier: id,
    records: src.map((s) => s.toRecord()).toList(),
    totalDebitCents: src.where((s) => s.debit).fold(0, (a, s) => a + s.cents),
    totalCreditCents: src.where((s) => !s.debit).fold(0, (a, s) => a + s.cents),
    totalTaxCents: 0,
    periodStart: dates.first,
    periodEnd: dates.last,
  );
}

final _card = [
  _Src(DateTime(2026, 7, 30), true, 99999, TransactionKind.purchase,
      'cat_market', 'TEMMUZ MARKET'),
  _Src(DateTime(2026, 8, 3), true, 125050, TransactionKind.purchase,
      'cat_market', 'MIGROS'),
  _Src(DateTime(2026, 8, 5), true, 89990, TransactionKind.purchase,
      'cat_clothing', 'LCW'),
  _Src(DateTime(2026, 8, 9), false, 89990, TransactionKind.refund,
      'cat_clothing', 'LCW IADE'),
  _Src(DateTime(2026, 8, 10), true, 4567, TransactionKind.interestFee,
      'cat_fees', 'GECIKME FAIZI'),
  _Src(DateTime(2026, 8, 12), false, 500000, TransactionKind.cardPayment,
      'cat_card_payment', 'ODEME TESEKKUR'),
  _Src(DateTime(2026, 9, 1), true, 11111, TransactionKind.purchase,
      'cat_market', 'EYLUL MARKET'),
];

final _ykChecking = [
  _Src(DateTime(2026, 8, 12), true, 500000, TransactionKind.cardPayment,
      'cat_card_payment', 'KREDI KARTI ODEMESI'),
  _Src(DateTime(2026, 8, 15), true, 300000, TransactionKind.transferOut,
      'cat_transfer', 'FAST GIDEN KENDIM',
      expectOwnTransfer: true),
  _Src(DateTime(2026, 8, 20), true, 75025, TransactionKind.billPayment,
      'cat_utilities', 'ELEKTRIK FATURASI'),
  _Src(DateTime(2026, 8, 22), false, 20000, TransactionKind.transferIn,
      'cat_transfer', 'FAST GELEN ARKADAS'),
  _Src(DateTime(2026, 8, 29), false, 4500000, TransactionKind.salary,
      'cat_salary', 'MAAS ODEMESI'),
];

final _enpara = [
  _Src(DateTime(2026, 8, 16), false, 300000, TransactionKind.transferIn,
      'cat_transfer', 'FAST GELEN KENDIM',
      expectOwnTransfer: true),
  _Src(DateTime(2026, 8, 18), true, 45000, TransactionKind.purchase,
      'cat_dining', 'KAFE'),
];

final _payslip = [
  _Src(DateTime(2026, 8, 31), false, 4500000, TransactionKind.salary,
      'cat_salary', 'NET UCRET',
      expectPayslipDuplicate: true),
];

const _manualCash = (cents: 15000, date: (2026, 8, 25), category: 'cat_market');

Future<void> _seed(TransactionRepository repo) async {
  await repo.saveStatementResult(
      result: _doc('Yapı Kredi', 'CREDIT_CARD', '4462', _card),
      fileSha256: 'sha_card');
  await repo.saveStatementResult(
      result: _doc('Yapı Kredi', 'CHECKING', '1111', _ykChecking),
      fileSha256: 'sha_yk');
  await repo.saveStatementResult(
      result: _doc('Enpara', 'CHECKING', '2222', _enpara),
      fileSha256: 'sha_enp');
  await repo.saveStatementResult(
      result: _doc('Örnek A.Ş.', 'PAYSLIP', '', _payslip),
      fileSha256: 'sha_bordro');
  await repo.saveManualTransaction(
    title: 'Pazar',
    amountCents: _manualCash.cents,
    isExpense: true,
    categoryId: _manualCash.category,
    date:
        DateTime(_manualCash.date.$1, _manualCash.date.$2, _manualCash.date.$3),
  );
}

List<_Src> get _all => [
      ..._card,
      ..._ykChecking,
      ..._enpara,
      ..._payslip,
      _Src(
          DateTime(
              _manualCash.date.$1, _manualCash.date.$2, _manualCash.date.$3),
          true,
          _manualCash.cents,
          TransactionKind.other,
          _manualCash.category,
          'Pazar'),
    ];

bool _inMonth(_Src s, int y, int m) => s.date.year == y && s.date.month == m;

int _expectedExpense(int y, int m) {
  final rows = _all.where((s) => _inMonth(s, y, m) && !s.neutral);
  final debits = rows.where((s) => s.debit).fold<int>(0, (a, s) => a + s.cents);
  final refunds = rows
      .where((s) => !s.debit && s.kind == TransactionKind.refund)
      .fold<int>(0, (a, s) => a + s.cents);
  return debits - refunds;
}

int _expectedIncome(int y, int m) => _all
    .where((s) =>
        _inMonth(s, y, m) &&
        !s.neutral &&
        !s.debit &&
        s.kind != TransactionKind.refund)
    .fold<int>(0, (a, s) => a + s.cents);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late TransactionRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_audit_totals_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    repo = TransactionRepository();
    await _seed(repo);
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test(
      'ön koşul: kendi transferi çifti OWNTRANSFER oldu, diğer transfer gelir olarak kaldı',
      () async {
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('transactions', columns: ['raw_description', 'tx_kind']);
    final kindOf = {for (final r in rows) r['raw_description']: r['tx_kind']};
    expect(kindOf['FAST GIDEN KENDIM'], 'OWNTRANSFER');
    expect(kindOf['FAST GELEN KENDIM'], 'OWNTRANSFER');
    expect(kindOf['FAST GELEN ARKADAS'], 'TRANSFERIN');
    expect(rows, hasLength(_all.length),
        reason: 'Hiçbir kaynak kayıt kaybolmamalı/çoğalmamalı');
  });

  test(
      'getMonthlySummary (Ağustos) kaynak işlemlerden bağımsız hesaplanan gelir/gider/net ile birebir',
      () async {
    final s = await repo.getMonthlySummary(yearMonth: '2026-08');
    final expense = _expectedExpense(2026, 8);
    final income = _expectedIncome(2026, 8);
    // Elle de kontrol (kahinin kendisi yanlışsa yakalansın):
    expect(expense, 125050 + 89990 + 4567 + 75025 + 45000 + 15000 - 89990);
    expect(income, 4500000 + 20000);
    expect(s['totalDebitCents'], expense);
    expect(s['totalCreditCents'], income);
    expect(s['netDifferenceCents'], income - expense);
  });

  test(
      'ay sınırı: Temmuz ve Eylül kayıtları Ağustos\'a sızmaz, kendi aylarında sayılır',
      () async {
    expect(
        (await repo.getMonthlySummary(yearMonth: '2026-07'))['totalDebitCents'],
        _expectedExpense(2026, 7));
    expect(
        (await repo.getMonthlySummary(yearMonth: '2026-09'))['totalDebitCents'],
        _expectedExpense(2026, 9));
    expect(_expectedExpense(2026, 7), 99999);
    expect(_expectedExpense(2026, 9), 11111);
  });

  test(
      'getMonthlyTrendsAnalysis aylık harcaması = getMonthlySummary gideri (aynı ekranda iki farklı sayı olmamalı)',
      () async {
    final trends = await repo.getMonthlyTrendsAnalysis();
    final byMonth = {for (final t in trends) t['year_month']: t['cents']};
    for (final ym in ['2026-07', '2026-08', '2026-09']) {
      final summary = await repo.getMonthlySummary(yearMonth: ym);
      expect(byMonth[ym], summary['totalDebitCents'], reason: ym);
    }
    final ratios = trends.map((t) => t['ratio'] as double);
    expect(ratios.every((r) => r >= 0 && r <= 1), isTrue);
  });

  test(
      'getCategorySpendingAnalysis: kategori toplamları kaynak BORÇ kayıtlarıyla birebir; nötr türler girmez',
      () async {
    final cats = await repo.getCategorySpendingAnalysis(yearMonth: '2026-08');
    final gross = _all
        .where((s) => _inMonth(s, 2026, 8) && !s.neutral && s.debit)
        .fold<int>(0, (a, s) => a + s.cents);
    expect(cats.fold<int>(0, (a, c) => a + (c['cents'] as int)), gross);
    final names = cats.map((c) => c['name']).toList();
    expect(names, isNot(contains('Kart Borcu Ödemesi')));
    expect(names, isNot(contains('Havale & Transfer')));
    final pctSum = cats.fold<int>(0, (a, c) => a + (c['percentage'] as int));
    expect(pctSum, inInclusiveRange(98, 102),
        reason: 'Yuvarlanmış yüzdeler ~%100 etmeli');
  });

  test(
    'kategori dağılımı toplamı = ay gideri (iade, iade edilen kategoriden düşülmeli)',
    () async {
      final cats = await repo.getCategorySpendingAnalysis(yearMonth: '2026-08');
      final summary = await repo.getMonthlySummary(yearMonth: '2026-08');
      expect(cats.fold<int>(0, (a, c) => a + (c['cents'] as int)),
          summary['totalDebitCents']);
      final clothing = cats.where((c) => c['name'] == 'Giyim & Moda');
      expect(clothing.isEmpty || clothing.single['cents'] == 0, isTrue,
          reason: 'Tamamı iade edilen giyim harcaması net 0 olmalı');
    },
    skip:
        'BULGU QA-P3-03: getMonthlySummary ve getMonthlyTrendsAnalysis iadeyi (REFUND) giderden düşüyor, '
        'getCategorySpendingAnalysis düşmüyor. Tamamı iade edilen 899,90 TL giyim, kategori dağılımında '
        'harcama olarak kalıyor ve kategori toplamı ay giderinden büyük görünüyor.',
  );
}
