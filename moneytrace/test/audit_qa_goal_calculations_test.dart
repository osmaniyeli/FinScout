// test/audit_qa_goal_calculations_test.dart
//
// DENETİM (QA 3/5) — Birikim hedefi hesapları: FinancialGoal (kalan tutar, kalan ay, aylık öneri),
// GoalCalculatorService.calculateSummary (özet başlık) ve GoalRepository (biriken tutar = katkı
// geçmişi toplamı değişmezi). Önceden yalnız adaptive_layout_test'te render ediliyordu; hesap
// doğruluğu hiç test edilmiyordu. Tutarlar uydurma örnek sayılardır.
//
// GoalRepository testleri gerçek AppDatabase şemasına (assets/sql/*) karşı sqflite FFI + sahte
// path_provider ile çalışır (bkz. own_transfer_reconciliation_test.dart ile aynı desen).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moneytrace/core/database/app_database.dart';
import 'package:moneytrace/features/goals/models/financial_goal.dart';
import 'package:moneytrace/features/goals/repositories/goal_repository.dart';
import 'package:moneytrace/features/goals/services/goal_calculator_service.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

FinancialGoal _goal({
  String id = 'g1',
  required int target,
  required int saved,
  DateTime? targetDate,
  GoalStatus status = GoalStatus.active,
}) {
  final now = DateTime.now();
  return FinancialGoal(
    id: id,
    title: 'Hedef $id',
    category: GoalCategory.other,
    targetAmountCents: target,
    currentSavedCents: saved,
    targetDate: targetDate ?? DateTime(now.year, now.month + 6, 15),
    status: status,
    createdAt: now,
  );
}

void main() {
  group('FinancialGoal', () {
    test(
        'kalan tutar ve ilerleme: kuruş hassasiyeti, %100 tavan, hedef 0 güvenli',
        () {
      final g = _goal(target: 1000000, saved: 333333);
      expect(g.remainingAmountCents, 666667);
      expect(g.progressPercentage, 33.3);
      expect(_goal(target: 1000, saved: 5000).progressPercentage, 100.0);
      expect(_goal(target: 1000, saved: 5000).remainingAmountCents, 0);
      expect(_goal(target: 0, saved: 0).progressPercentage, 0.0);
    });

    test(
        'kalan ay: bu ay içindeki tarih 1, geçmiş tarih 0 + "Tarihi geçti", 6 ay sonrası 6',
        () {
      final now = DateTime.now();
      final thisMonthEnd = DateTime(now.year, now.month + 1, 0);
      expect(
          _goal(target: 100, saved: 0, targetDate: thisMonthEnd)
              .monthsRemaining,
          1);
      final past = _goal(
          target: 100,
          saved: 0,
          targetDate: DateTime(now.year, now.month, now.day - 1));
      expect(past.isOverdue, isTrue);
      expect(past.monthsRemaining, 0);
      expect(past.timeLabel, 'Tarihi geçti');
      expect(past.recommendedMonthlySavingsCents, 100,
          reason: 'Tarihi geçmiş hedefte kalan tutarın tamamı önerilir');
      expect(
          _goal(
                  target: 100,
                  saved: 0,
                  targetDate: DateTime(now.year, now.month + 6, 1))
              .monthsRemaining,
          6);
      // Bugün tarihli hedef geçmiş sayılmaz
      expect(
          _goal(
                  target: 100,
                  saved: 0,
                  targetDate: DateTime(now.year, now.month, now.day))
              .isOverdue,
          isFalse);
    });

    test('aylık öneri tam bölünüyorsa birebir; tamamlanmış hedefte 0', () {
      final now = DateTime.now();
      final g = _goal(
          target: 1200000,
          saved: 0,
          targetDate: DateTime(now.year, now.month + 12, 1));
      expect(g.monthsRemaining, 12);
      expect(g.recommendedMonthlySavingsCents, 100000);
      expect(_goal(target: 500, saved: 500).recommendedMonthlySavingsCents, 0);
      expect(_goal(target: 500, saved: 500).timeLabel, 'Tamamlandı');
    });

    test(
      'aylık öneri × kalan ay, kalan tutarı KARŞILAMALI (yuvarlama hedefe yetişmeyi bozmamalı)',
      () {
        final now = DateTime.now();
        // Kalan 100,00 TL, 3 ay: 33,33 × 3 = 99,99 → hedef tarihinde 1 kuruş eksik kalır.
        // Daha büyük örnek: 1.000.000,01 TL / 7 ay.
        for (final (remaining, months) in [
          (10000, 3),
          (100000001, 7),
          (1000, 6)
        ]) {
          final g = _goal(
              target: remaining,
              saved: 0,
              targetDate: DateTime(now.year, now.month + months, 1));
          expect(g.monthsRemaining, months);
          expect(g.recommendedMonthlySavingsCents * months,
              greaterThanOrEqualTo(remaining),
              reason:
                  'remaining=$remaining months=$months öneri=${g.recommendedMonthlySavingsCents}');
        }
      },
      skip:
          'BULGU QA-P3-02: FinancialGoal.recommendedMonthlySavingsCents `.round()` kullanıyor; '
          'öneriye uyan kullanıcı hedef tarihinde birkaç kuruş eksik kalabilir (ör. 100 TL/3 ay = 33,33 → 99,99). '
          '"Yetişmek için gereken" tutar için yukarı yuvarlama (ceil) beklenir.',
    );
  });

  group('GoalCalculatorService.calculateSummary', () {
    test('boş liste: sıfır özet', () {
      final s = GoalCalculatorService.calculateSummary(const []);
      expect(s.totalTargetCents, 0);
      expect(s.activeGoalsCount, 0);
      expect(s.overallProgressPercentage, 0.0);
    });

    test(
        'toplamlar kaynak hedeflerden yeniden hesaplanınca birebir tutar; tamamlanan aylık öneriye girmez',
        () {
      final now = DateTime.now();
      final goals = [
        _goal(
            id: 'a',
            target: 1200000,
            saved: 300000,
            targetDate: DateTime(now.year, now.month + 9, 1)),
        _goal(id: 'b', target: 500000, saved: 500000), // tamamlandı (birikimle)
        _goal(
            id: 'c',
            target: 250000,
            saved: 10000,
            status: GoalStatus.completed), // elle tamamlandı
        _goal(
            id: 'd',
            target: 99999,
            saved: 1,
            targetDate: DateTime(now.year, now.month + 2, 1)),
      ];
      final s = GoalCalculatorService.calculateSummary(goals);

      final expectedTarget =
          goals.fold<int>(0, (a, g) => a + g.targetAmountCents);
      final expectedSaved =
          goals.fold<int>(0, (a, g) => a + g.currentSavedCents);
      expect(s.totalTargetCents, expectedTarget);
      expect(s.totalSavedCents, expectedSaved);
      expect(s.completedGoalsCount, 2);
      expect(s.activeGoalsCount, 2);
      expect(
          s.totalMonthlyRecommendedSavingsCents,
          goals[0].recommendedMonthlySavingsCents +
              goals[3].recommendedMonthlySavingsCents);
      expect(
          s.overallProgressPercentage,
          double.parse(
              (expectedSaved / expectedTarget * 100).toStringAsFixed(1)));
    });

    test(
        'mevcut davranış (belgeleme): DURAKLATILMIŞ hedef "aktif" sayılır ve aylık öneriye girer',
        () {
      // Ürün kararı açık: duraklatılan hedefin aylık önerisi toplam aylık birikim önerisini şişirir.
      final s = GoalCalculatorService.calculateSummary([
        _goal(id: 'p', target: 600000, saved: 0, status: GoalStatus.paused),
      ]);
      expect(s.activeGoalsCount, 1);
      expect(s.totalMonthlyRecommendedSavingsCents, greaterThan(0));
    });

    test(
      'özet "kalan" tutar = hedeflerin tek tek kalanlarının toplamı (fazla biriken hedef diğerinin açığını kapatmamalı)',
      () {
        // A hedefi fazlasıyla doldu (100 TL hedef, 200 TL birikim); B hedefine hiç para yok (100 TL).
        // Kullanıcının hâlâ biriktirmesi gereken 100 TL'dir; özet ise "kalan 0 / %100" gösteriyor.
        final goals = [
          _goal(id: 'a', target: 10000, saved: 20000),
          _goal(id: 'b', target: 10000, saved: 0),
        ];
        final s = GoalCalculatorService.calculateSummary(goals);
        final perGoalRemaining =
            goals.fold<int>(0, (a, g) => a + g.remainingAmountCents);
        expect(perGoalRemaining, 10000);
        expect(s.remainingTargetCents, perGoalRemaining);
        expect(s.overallProgressPercentage, lessThan(100.0));
      },
      skip:
          'BULGU QA-P2-01: GoalCalculatorService.calculateSummary kalan tutarı max(toplamHedef − toplamBirikim, 0) '
          've ilerlemeyi Σbirikim/Σhedef ile hesaplıyor; bir hedefteki fazla birikim başka hedefin açığını "kapatıyor" → '
          'GoalSummaryHeader "%100 Ulaşıldı" gösterirken bir hedef hiç fonlanmamış. Kalan = Σ goal.remainingAmountCents, ilerleme '
          'için birikim hedef başına min(saved, target) ile sınırlanmalı.',
    );
  });

  group('GoalRepository (gerçek SQLite)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('finscout_audit_goals_');
      PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    Future<int> contributionsSum(GoalRepository repo, String id) async =>
        (await repo.getContributions(id))
            .fold<int>(0, (a, c) => a + c.amountCents);

    test(
        'değişmez: biriken tutar = katkı geçmişi toplamı (ekle/sil/başlangıç birikimi)',
        () async {
      final repo = GoalRepository();
      await repo.insertGoal(_goal(id: 'ev', target: 50000000, saved: 1234567));
      var g = (await repo.getAllGoals()).single;
      expect(g.currentSavedCents, 1234567);
      expect(await contributionsSum(repo, 'ev'), g.currentSavedCents);

      await repo.addContribution(goalId: 'ev', amountCents: 250050);
      await repo.addContribution(goalId: 'ev', amountCents: 1);
      g = (await repo.getAllGoals()).single;
      expect(g.currentSavedCents, 1234567 + 250050 + 1);
      expect(await contributionsSum(repo, 'ev'), g.currentSavedCents);

      final toDelete = (await repo.getContributions('ev'))
          .firstWhere((c) => c.amountCents == 250050);
      await repo.deleteContribution(toDelete);
      g = (await repo.getAllGoals()).single;
      expect(g.currentSavedCents, 1234568);
      expect(await contributionsSum(repo, 'ev'), g.currentSavedCents);
    });

    test(
        'hedef güncellemesi katkı geçmişini silmez (REPLACE/CASCADE regresyonu)',
        () async {
      final repo = GoalRepository();
      await repo.insertGoal(_goal(id: 'tatil', target: 100000, saved: 0));
      await repo.addContribution(goalId: 'tatil', amountCents: 40000);
      await repo.updateGoal(
          id: 'tatil',
          title: 'Yaz tatili',
          category: GoalCategory.travel,
          targetAmountCents: 150000,
          targetDate: DateTime(DateTime.now().year + 1, 7, 1));
      final g = (await repo.getAllGoals()).single;
      expect(g.title, 'Yaz tatili');
      expect(g.targetAmountCents, 150000);
      expect(g.currentSavedCents, 40000);
      expect(await repo.getContributions('tatil'), hasLength(1));
    });

    test('hedef silinince katkıları da silinir (yetim satır kalmaz)', () async {
      final repo = GoalRepository();
      await repo.insertGoal(_goal(id: 'arac', target: 100000, saved: 5000));
      await repo.addContribution(goalId: 'arac', amountCents: 100);
      await repo.deleteGoal('arac');
      expect(await repo.getAllGoals(), isEmpty);
      expect(await repo.getContributions('arac'), isEmpty);
    });
  });
}
