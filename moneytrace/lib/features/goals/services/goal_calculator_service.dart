// lib/features/goals/services/goal_calculator_service.dart

import '../models/financial_goal.dart';

class GoalsSummary {
  final int totalTargetCents;
  final int totalSavedCents;
  final int remainingTargetCents;
  final double overallProgressPercentage;
  final int totalMonthlyRecommendedSavingsCents;
  final int activeGoalsCount;
  final int completedGoalsCount;

  const GoalsSummary({
    required this.totalTargetCents,
    required this.totalSavedCents,
    required this.remainingTargetCents,
    required this.overallProgressPercentage,
    required this.totalMonthlyRecommendedSavingsCents,
    required this.activeGoalsCount,
    required this.completedGoalsCount,
  });

  factory GoalsSummary.empty() {
    return const GoalsSummary(
      totalTargetCents: 0,
      totalSavedCents: 0,
      remainingTargetCents: 0,
      overallProgressPercentage: 0.0,
      totalMonthlyRecommendedSavingsCents: 0,
      activeGoalsCount: 0,
      completedGoalsCount: 0,
    );
  }
}

class GoalCalculatorService {
  static GoalsSummary calculateSummary(List<FinancialGoal> goals) {
    if (goals.isEmpty) {
      return GoalsSummary.empty();
    }

    int totalTarget = 0;
    int totalSaved = 0;
    int monthlyRecTotal = 0;
    int activeCount = 0;
    int completedCount = 0;

    for (final goal in goals) {
      totalTarget += goal.targetAmountCents;
      totalSaved += goal.currentSavedCents;

      if (goal.isCompleted || goal.status == GoalStatus.completed) {
        completedCount++;
      } else {
        activeCount++;
        monthlyRecTotal += goal.recommendedMonthlySavingsCents;
      }
    }

    final int remaining = totalTarget > totalSaved ? totalTarget - totalSaved : 0;
    final double progress = totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0.0;

    return GoalsSummary(
      totalTargetCents: totalTarget,
      totalSavedCents: totalSaved,
      remainingTargetCents: remaining,
      overallProgressPercentage: progress > 100.0 ? 100.0 : double.parse(progress.toStringAsFixed(1)),
      totalMonthlyRecommendedSavingsCents: monthlyRecTotal,
      activeGoalsCount: activeCount,
      completedGoalsCount: completedCount,
    );
  }

  /// "İzci" (Scout) zeka motorundan hedeflere yönelik dinamik geri bildirim
  static String generateScoutGoalInsight(GoalsSummary summary, List<FinancialGoal> goals) {
    if (goals.isEmpty) {
      return '🦉 İzci: Henüz bir hedef belirlemedin! Bir tekne veya ev hayali bütçeni disipline sokmanın en iyi yoludur.';
    }

    if (summary.completedGoalsCount > 0 && summary.activeGoalsCount == 0) {
      return '🦉 İzci: Tebrikler! Bütün hedeflerini tamamladın. Kendine yeni ufuklar ve büyük hayaller çizme vakti!';
    }

    if (summary.overallProgressPercentage >= 75.0) {
      return '🦉 İzci: Hedeflerinin son düzlüğündesin! %${summary.overallProgressPercentage.toStringAsFixed(0)} tamamlandı, biraz daha gayret!';
    }

    // En yakın hedefe göre motive et
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    if (activeGoals.isNotEmpty) {
      activeGoals.sort((a, b) => a.monthsRemaining.compareTo(b.monthsRemaining));
      final closest = activeGoals.first;
      return '🦉 İzci: "${closest.title}" için ${closest.monthsRemaining} ayın kaldı. Gereksiz abonelikleri kısıp buraya aktaralım!';
    }

    return '🦉 İzci: Düzenli birikim zenginliğin anahtarıdır. Ayda planlanan tutarları kumbaraya atmayı unutma!';
  }

  /// Akıllı Birikim Öneri Motoru (Madde 14):
  /// Kullanıcının geçmiş harcama analizine dayanarak hedefe ulaşması için
  /// ayda ne kadar kenara ayırması gerektiğini ve hangi gereksiz giderlerden
  /// kısılabileceğini hesaplar.
  static List<String> generateSmartSavingsAdvice({
    required List<FinancialGoal> goals,
    required List<Map<String, dynamic>> categorySpending,
  }) {
    final List<String> adviceList = [];
    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    if (activeGoals.isEmpty) return adviceList;

    // 1. En yakın vadeli aktif hedef
    activeGoals.sort((a, b) => a.monthsRemaining.compareTo(b.monthsRemaining));
    final target = activeGoals.first;
    final remainingMonths = target.monthsRemaining > 0 ? target.monthsRemaining : 1;
    final remainingCents = target.targetAmountCents - target.currentSavedCents;
    final monthlyNeededCents = (remainingCents / remainingMonths).round();
    final monthlyNeededTL = (monthlyNeededCents / 100).toStringAsFixed(0);

    adviceList.add(
      '🎯 "${target.title}" hedefinize $remainingMonths ayda ulaşmak için ayda en az ₺$monthlyNeededTL düzenli birikim yapmanız gerekiyor.',
    );

    // 2. Geçmiş harcama kategorilerinden kısma potansiyeli analizi
    for (final cat in categorySpending) {
      final name = (cat['name'] as String? ?? '').toLowerCase();
      final cents = (cat['cents'] as int? ?? 0);
      final tl = (cents / 100).round();

      if (tl > 1000 && (name.contains('yeme') || name.contains('restoran') || name.contains('kafe') || name.contains('dışarı'))) {
        final cutAmount = (tl * 0.20).round();
        adviceList.add(
          '💡 Restoran ve dışarıda yeme-içme harcamalarınızdan %20 (yaklaşık ₺$cutAmount) tasarruf ederek birikim hızınızı artırabilirsiniz.',
        );
      } else if (tl > 800 && (name.contains('eğlence') || name.contains('hobi') || name.contains('oyun'))) {
        final cutAmount = (tl * 0.25).round();
        adviceList.add(
          '💡 Eğlence ve hobi harcamalarınızdan ₺$cutAmount kısarak bu tutarı doğrudan "${target.title}" hedefinize aktarabilirsiniz.',
        );
      } else if (tl > 1500 && (name.contains('giyim') || name.contains('alışveriş') || name.contains('avm'))) {
        final cutAmount = (tl * 0.15).round();
        adviceList.add(
          '💡 İsteğe bağlı giyim/alışveriş harcamalarınızı erteleyerek hedefinize 1 ay daha erken ulaşabilirsiniz.',
        );
      }
    }

    if (adviceList.length == 1) {
      adviceList.add(
        '💡 Düzenli küçük tasarruflar büyük hedeflere ulaştırır. Sabit fatura ve aboneliklerinizi gözden geçirerek başlayın.',
      );
    }

    return adviceList;
  }
}
