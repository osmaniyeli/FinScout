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

    final int remaining =
        totalTarget > totalSaved ? totalTarget - totalSaved : 0;
    final double progress =
        totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0.0;

    return GoalsSummary(
      totalTargetCents: totalTarget,
      totalSavedCents: totalSaved,
      remainingTargetCents: remaining,
      overallProgressPercentage:
          progress > 100.0 ? 100.0 : double.parse(progress.toStringAsFixed(1)),
      totalMonthlyRecommendedSavingsCents: monthlyRecTotal,
      activeGoalsCount: activeCount,
      completedGoalsCount: completedCount,
    );
  }
}
