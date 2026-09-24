// lib/features/goals/repositories/goal_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../models/financial_goal.dart';

class GoalRepository {
  final AppDatabase _dbProvider;

  GoalRepository({AppDatabase? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  static String _dateOnly(DateTime d) => d.toIso8601String().split('T')[0];

  static String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<List<FinancialGoal>> getAllGoals() async {
    final db = await _dbProvider.database;
    final rows = await db.query('goals', orderBy: 'created_at DESC');

    return rows.map<FinancialGoal>((r) {
      GoalStatus status;
      switch (r['status'] as String?) {
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
        category: GoalCategoryExtension.fromDb(r['category_type'] as String?),
        targetAmountCents: r['target_amount_cents'] as int,
        currentSavedCents: r['current_saved_cents'] as int,
        currency: r['currency_code'] as String? ?? 'TRY',
        targetDate: DateTime.parse(r['target_date'] as String),
        monthlyPlanCents: r['monthly_plan_cents'] as int?,
        status: status,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
    }).toList();
  }

  /// Yeni hedef ekler. Başlangıç birikimi varsa katkı geçmişine de ilk kayıt olarak yazılır,
  /// böylece "biriken" tutar ile katkı geçmişinin toplamı tutarlı kalır.
  Future<void> insertGoal(FinancialGoal goal) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn.insert('goals', goal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort);
      if (goal.currentSavedCents > 0) {
        await txn.insert('goal_contributions', {
          'id': _newId('contrib'),
          'goal_id': goal.id,
          'amount_cents': goal.currentSavedCents,
          'contribution_date': _dateOnly(goal.createdAt),
          'note': 'Başlangıç birikimi',
          'created_at': goal.createdAt.millisecondsSinceEpoch,
        });
      }
    });
  }

  /// Hedefin ad, kategori, hedef tutar ve hedef tarihini günceller.
  /// Biriken tutara dokunmaz (o yalnız katkılarla değişir).
  /// Not: REPLACE kullanılmaz; REPLACE satırı silip yeniden yazdığı için
  /// ON DELETE CASCADE ile katkı geçmişini silerdi.
  Future<void> updateGoal({
    required String id,
    required String title,
    required GoalCategory category,
    required int targetAmountCents,
    required DateTime targetDate,
  }) async {
    final db = await _dbProvider.database;
    await db.update(
      'goals',
      {
        'title': title,
        'category_type': category.name,
        'target_amount_cents': targetAmountCents,
        'target_date': _dateOnly(targetDate),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hedefi ve tüm katkı geçmişini siler.
  Future<void> deleteGoal(String id) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn
          .delete('goal_contributions', where: 'goal_id = ?', whereArgs: [id]);
      await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Hedefin katkı geçmişi, en yeni önce.
  Future<List<GoalContribution>> getContributions(String goalId) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'goal_contributions',
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'contribution_date DESC, created_at DESC',
    );
    return rows
        .map((r) => GoalContribution(
              id: r['id'] as String,
              goalId: r['goal_id'] as String,
              amountCents: r['amount_cents'] as int,
              date: DateTime.parse(r['contribution_date'] as String),
              note: r['note'] as String?,
            ))
        .toList();
  }

  Future<void> addContribution({
    required String goalId,
    required int amountCents,
    String? note,
  }) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      final now = DateTime.now();
      await txn.insert('goal_contributions', {
        'id': _newId('contrib'),
        'goal_id': goalId,
        'amount_cents': amountCents,
        'contribution_date': _dateOnly(now),
        'note': note,
        'created_at': now.millisecondsSinceEpoch,
      });

      // Hedefteki birikim tutarını güncelle
      await txn.rawUpdate('''
        UPDATE goals
        SET current_saved_cents = current_saved_cents + ?
        WHERE id = ?
      ''', [amountCents, goalId]);
    });
  }

  /// Hatalı girilmiş bir katkıyı siler ve biriken tutardan düşer (0'ın altına inmez).
  Future<void> deleteContribution(GoalContribution c) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      await txn
          .delete('goal_contributions', where: 'id = ?', whereArgs: [c.id]);
      await txn.rawUpdate('''
        UPDATE goals
        SET current_saved_cents = MAX(current_saved_cents - ?, 0)
        WHERE id = ?
      ''', [c.amountCents, c.goalId]);
    });
  }
}
