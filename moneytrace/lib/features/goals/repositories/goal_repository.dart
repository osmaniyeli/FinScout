// lib/features/goals/repositories/goal_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../models/financial_goal.dart';

class GoalRepository {
  final AppDatabase _dbProvider;

  GoalRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  Future<List<FinancialGoal>> getAllGoals() async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'goals',
      orderBy: 'created_at DESC',
    );

    return rows.map((r) {
      GoalCategory category;
      switch (r['category_type'] as String) {
        case 'vehicle':
          category = GoalCategory.vehicle;
          break;
        case 'house':
          category = GoalCategory.house;
          break;
        case 'motorcycle':
          category = GoalCategory.motorcycle;
          break;
        case 'boat':
          category = GoalCategory.boat;
          break;
        case 'gift':
          category = GoalCategory.gift;
          break;
        case 'travel':
          category = GoalCategory.travel;
          break;
        case 'electronics':
          category = GoalCategory.electronics;
          break;
        default:
          category = GoalCategory.other;
      }

      GoalStatus status;
      switch (r['status'] as String) {
        case 'COMPLETED':
          status = GoalStatus.completed;
          break;
        case 'PAUSED':
          status = GoalStatus.paused;
          break;
        default:
          status = GoalStatus.active;
      }

      return FinancialGoal(
        id: r['id'] as String,
        title: r['title'] as String,
        category: category,
        targetAmountCents: r['target_amount_cents'] as int,
        currentSavedCents: r['current_saved_cents'] as int,
        currencyCode: r['currency_code'] as String? ?? 'TRY',
        targetDate: DateTime.parse(r['target_date'] as String),
        monthlyPlanCents: r['monthly_plan_cents'] as int?,
        status: status,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
    }).toList();
  }

  Future<void> insertGoal(FinancialGoal goal) async {
    final db = await _dbProvider.database;
    await db.insert(
      'goals',
      {
        'id': goal.id,
        'title': goal.title,
        'category_type': goal.category.name,
        'target_amount_cents': goal.targetAmountCents,
        'current_saved_cents': goal.currentSavedCents,
        'currency_code': goal.currencyCode,
        'target_date': goal.targetDate.toIso8601String().split('T')[0],
        'monthly_plan_cents': goal.monthlyPlanCents,
        'status': goal.status.name.toUpperCase(),
        'created_at': goal.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addContribution({
    required String goalId,
    required int amountCents,
    String? note,
  }) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('goal_contributions', {
        'id': 'contrib_$nowMs',
        'goal_id': goalId,
        'amount_cents': amountCents,
        'contribution_date': DateTime.now().toIso8601String().split('T')[0],
        'note': note,
        'created_at': nowMs,
      });

      // Hedefteki birikim tutarını güncelle
      await txn.rawUpdate('''
        UPDATE goals 
        SET current_saved_cents = current_saved_cents + ?
        WHERE id = ?
      ''', [amountCents, goalId]);
    });
  }
}
