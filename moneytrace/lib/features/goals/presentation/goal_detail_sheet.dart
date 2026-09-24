// lib/features/goals/presentation/goal_detail_sheet.dart

import 'package:flutter/material.dart';
import '../../../core/services/data_changes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../models/financial_goal.dart';
import '../repositories/goal_repository.dart';
import 'add_goal_sheet.dart';
import 'goal_contribution_dialog.dart';

/// Hedef detayı: özet, birikim ekleme, düzenleme, silme ve katkı geçmişi.
/// Hedef silinirse sayfa `true` ile kapanır.
class GoalDetailSheet extends StatefulWidget {
  final FinancialGoal goal;
  final GoalRepository repository;

  const GoalDetailSheet({
    Key? key,
    required this.goal,
    required this.repository,
  }) : super(key: key);

  @override
  State<GoalDetailSheet> createState() => _GoalDetailSheetState();
}

class _GoalDetailSheetState extends State<GoalDetailSheet> {
  late FinancialGoal _goal;
  List<GoalContribution> _contributions = [];
  bool _loadingHistory = true;
  bool _busy = false;

  GoalRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _reload();
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _reload() async {
    try {
      final goals = await _repo.getAllGoals();
      final contributions = await _repo.getContributions(_goal.id);
      if (!mounted) return;
      setState(() {
        for (final g in goals) {
          if (g.id == _goal.id) _goal = g;
        }
        _contributions = contributions;
        _loadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _toast(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.incomeGreen : null,
    ));
  }

  Future<void> _addContribution() async {
    final cents = await showGoalContributionDialog(context, _goal);
    if (cents == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.addContribution(goalId: _goal.id, amountCents: cents);
      DataChanges.notify();
      await _reload();
      if (mounted) {
        _toast('${CurrencyNormalizer.formatCents(cents)} birikim eklendi.',
            success: true);
      }
    } catch (_) {
      if (mounted) _toast('Birikim kaydedilemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGoalSheet(
        initialGoal: _goal,
        onSave: (g) => _repo.updateGoal(
          id: g.id,
          title: g.title,
          category: g.category,
          targetAmountCents: g.targetAmountCents,
          targetDate: g.targetDate,
        ),
      ),
    );
    if (saved == true && mounted) {
      DataChanges.notify();
      await _reload();
      if (mounted) _toast('Hedef güncellendi.', success: true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hedef silinsin mi?'),
        content: Text(
            '"${_goal.title}" hedefi ve tüm birikim geçmişi silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.expenseRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteGoal(_goal.id);
      DataChanges.notify();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Hedef silinemedi. Lütfen tekrar deneyin.');
      }
    }
  }

  Future<void> _deleteContribution(GoalContribution c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Katkı silinsin mi?'),
        content: Text(
            '${_formatDate(c.date)} tarihli ${CurrencyNormalizer.formatCents(c.amountCents)} tutarındaki katkı silinecek ve birikimden düşülecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.expenseRed),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteContribution(c);
      DataChanges.notify();
      await _reload();
      if (mounted) _toast('Katkı silindi.', success: true);
    } catch (_) {
      if (mounted) _toast('Katkı silinemedi. Lütfen tekrar deneyin.');
    }
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    final themeColor = goal.category.themeColor;

    String monthlyLabel;
    if (goal.isCompleted) {
      monthlyLabel = '-';
    } else if (goal.isOverdue) {
      monthlyLabel = CurrencyNormalizer.formatCents(goal.remainingAmountCents);
    } else {
      monthlyLabel =
          '${CurrencyNormalizer.formatCents(goal.recommendedMonthlySavingsCents)} / ay';
    }

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Başlık satırı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(goal.category.iconData, color: themeColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      Text(
                        '${goal.category.displayName} • ${goal.timeLabel}',
                        style: TextStyle(
                            fontSize: 12,
                            color: goal.isOverdue && !goal.isCompleted
                                ? AppColors.expenseRed
                                : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // İlerleme özeti
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _infoRow('Biriken',
                      CurrencyNormalizer.formatCents(goal.currentSavedCents),
                      color: AppColors.incomeGreen),
                  _infoRow('Hedef tutar',
                      CurrencyNormalizer.formatCents(goal.targetAmountCents)),
                  _infoRow(
                      'Kalan',
                      CurrencyNormalizer.formatCents(
                          goal.remainingAmountCents)),
                  _infoRow('Hedef tarihi', _formatDate(goal.targetDate)),
                  _infoRow(
                      goal.isOverdue && !goal.isCompleted
                          ? 'Tarih geçti, kalan tutar'
                          : 'Aylık gereken',
                      monthlyLabel,
                      color: themeColor),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: goal.progressPercentage / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '%${goal.progressPercentage.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: themeColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Eylemler
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _addContribution,
                icon: const Icon(Icons.savings_rounded, size: 18),
                label: const Text('Birikim ekle',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _edit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Düzenle'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expenseRed,
                      side: const BorderSide(color: AppColors.expenseRed),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Katkı geçmişi
            const Text(
              'Katkı geçmişi',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            if (_loadingHistory)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_contributions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Henüz katkı yok.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              ..._contributions.map((c) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      CurrencyNormalizer.formatCents(c.amountCents),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      c.note == null || c.note!.isEmpty
                          ? _formatDate(c.date)
                          : '${_formatDate(c.date)} • ${c.note}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.textMuted),
                      tooltip: 'Katkıyı sil',
                      onPressed: _busy ? null : () => _deleteContribution(c),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
