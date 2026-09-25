// lib/features/goals/presentation/goals_screen.dart

import 'package:flutter/material.dart';
import '../../../core/services/data_changes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/widgets/morphing_segmented_bar.dart';
import '../models/financial_goal.dart';
import '../services/goal_calculator_service.dart';
import '../repositories/goal_repository.dart';
import '../widgets/goal_summary_header.dart';
import '../widgets/goal_card_tile.dart';
import 'add_goal_sheet.dart';
import 'goal_contribution_dialog.dart';
import 'goal_detail_sheet.dart';
import '../../navigation/tab_add_actions.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> implements TabAddActions {
  final GoalRepository _goalRepository = GoalRepository();
  int _filterIndex = 0; // 0: Tümü, 1: Aktif, 2: Tamamlanan
  bool _isLoading = true;

  List<FinancialGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    // Sekme IndexedStack içinde canlı kalır; veri değişince (hedef, geri yükleme, sıfırlama) yeniden yükle.
    DataChanges.revision.addListener(_loadGoals);
    _loadGoals();
  }

  @override
  void dispose() {
    DataChanges.revision.removeListener(_loadGoals);
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      final dbGoals = await _goalRepository.getAllGoals();
      if (mounted) {
        setState(() {
          _goals = dbGoals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.incomeGreen : null,
    ));
  }

  Future<void> _openAddGoal() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddGoalSheet(onSave: _goalRepository.insertGoal),
    );
    if (saved == true && mounted) {
      DataChanges.notify();
      _toast('Hedef kaydedildi.', success: true);
    }
  }

  /// + menüsü: "Yeni hedef" ve (aktif hedef varsa) "Birikim ekle".
  @override
  List<TabAddAction> get addActions {
    final active = _goals.where((g) => !g.isCompleted).toList();
    return [
      TabAddAction(
        icon: Icons.flag_rounded,
        title: 'Yeni hedef',
        subtitle: 'Tutar ve tarih belirle',
        onSelected: _openAddGoal,
      ),
      if (active.isNotEmpty)
        TabAddAction(
          icon: Icons.savings_rounded,
          title: 'Birikim ekle',
          subtitle: active.length == 1
              ? '"${active.first.title}" hedefine'
              : 'Hedef seçerek',
          onSelected: () => _pickGoalForContribution(active),
        ),
    ];
  }

  Future<void> _pickGoalForContribution(List<FinancialGoal> active) async {
    if (active.length == 1) {
      await _addContribution(active.first);
      return;
    }
    final goal = await showModalBottomSheet<FinancialGoal>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Hangi hedefe birikim eklensin?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final g in active)
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: Icon(g.category.iconData,
                            color: g.category.themeColor),
                        title: Text(g.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(
                            '${CurrencyNormalizer.formatCents(g.currentSavedCents)} / ${CurrencyNormalizer.formatCents(g.targetAmountCents)}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                        onTap: () => Navigator.pop(ctx, g),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (goal != null && mounted) await _addContribution(goal);
  }

  Future<void> _addContribution(FinancialGoal goal) async {
    final cents = await showGoalContributionDialog(context, goal);
    if (cents == null || !mounted) return;
    try {
      await _goalRepository.addContribution(
          goalId: goal.id, amountCents: cents);
      DataChanges.notify();
      if (mounted) {
        _toast(
            '"${goal.title}" hedefine ${CurrencyNormalizer.formatCents(cents)} eklendi.',
            success: true);
      }
    } catch (_) {
      if (mounted) _toast('Birikim kaydedilemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> _showGoalDetail(FinancialGoal goal) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          GoalDetailSheet(goal: goal, repository: _goalRepository),
    );
    if (deleted == true && mounted) {
      _toast('Hedef silindi.', success: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = GoalCalculatorService.calculateSummary(_goals);

    List<FinancialGoal> filteredGoals = _goals;
    if (_filterIndex == 1) {
      filteredGoals = _goals.where((g) => !g.isCompleted).toList();
    } else if (_filterIndex == 2) {
      filteredGoals = _goals.where((g) => g.isCompleted).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Hedeflerim',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: AppColors.actionPrimary, size: 24),
            onPressed: _openAddGoal,
            tooltip: 'Hedef ekle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGoals,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Özet Kartı ve 2. Filtre (yalnız hedef varsa)
                    if (_goals.isNotEmpty) GoalSummaryHeader(summary: summary),
                    if (_goals.isNotEmpty)
                      MorphingSegmentedBar(
                        segments: [
                          'Tümü (${_goals.length})',
                          'Aktif (${summary.activeGoalsCount})',
                          'Tamamlanan (${summary.completedGoalsCount})',
                        ],
                        selectedIndex: _filterIndex,
                        onSelected: (idx) => setState(() => _filterIndex = idx),
                      ),

                    // 3. Hedef Kartları Listesi
                    if (_goals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFFDBEAFE)),
                                ),
                                child: const Icon(Icons.flag_rounded,
                                    size: 36, color: AppColors.actionPrimary),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Henüz hedef eklenmedi',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Bir birikim hedefi ekleyin; hedef tutarı, tarihi ve biriktirdiklerinizi buradan takip edin.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _openAddGoal,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Hedef ekle',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.actionPrimary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (filteredGoals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Bu filtrede hedef bulunamadı.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...filteredGoals.map((g) {
                        return GoalCardTile(
                          goal: g,
                          onTap: () => _showGoalDetail(g),
                          onAddContribution: () => _addContribution(g),
                        );
                      }),

                    const SizedBox(height: 84), // Navigasyon & FAB boşluğu
                  ],
                ),
              ),
            ),
    );
  }
}
