// lib/features/goals/presentation/goal_contribution_dialog.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../../core/utils/thousands_input_formatter.dart';
import '../models/financial_goal.dart';

/// Hedefe birikim ekleme diyaloğu. Girilen tutarı kuruş olarak döndürür; vazgeçilirse null.
/// Kaydı çağıran taraf yapar (başarı mesajı yalnız kayıt başarılı olursa gösterilir).
Future<int?> showGoalContributionDialog(
    BuildContext context, FinancialGoal goal) {
  return showDialog<int>(
    context: context,
    builder: (_) => _GoalContributionDialog(goal: goal),
  );
}

class _GoalContributionDialog extends StatefulWidget {
  final FinancialGoal goal;

  const _GoalContributionDialog({required this.goal});

  @override
  State<_GoalContributionDialog> createState() =>
      _GoalContributionDialogState();
}

class _GoalContributionDialogState extends State<_GoalContributionDialog> {
  final _controller = TextEditingController();
  String? _error;

  static const _quickAmountsTl = [500, 1000, 2500, 5000];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _currentCents => _controller.text.trim().isEmpty
      ? 0
      : CurrencyNormalizer.toMinorUnits(_controller.text);

  /// Hızlı tutar çipi alandaki değere ekler.
  void _addQuick(int tl) {
    final cents = _currentCents + tl * 100;
    final whole = ThousandsInputFormatter.format((cents ~/ 100).toString());
    final frac = cents % 100;
    setState(() {
      _controller.text =
          frac == 0 ? whole : '$whole,${frac.toString().padLeft(2, '0')}';
      _error = null;
    });
  }

  void _confirm() {
    final cents = _currentCents;
    if (cents <= 0) {
      setState(() => _error = 'Geçerli bir tutar girin.');
      return;
    }
    Navigator.pop(context, cents);
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Birikim ekle',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${goal.title}" hedefine eklenecek tutar. Kalan: ${CurrencyNormalizer.formatCents(goal.remainingAmountCents)}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [ThousandsInputFormatter()],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              prefixText: '₺ ',
              labelText: 'Tutar',
              hintText: '0',
              errorText: _error,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickAmountsTl.map((tl) {
              return ActionChip(
                label: Text(
                  '+${CurrencyNormalizer.formatCents(tl * 100).replaceAll(',00', '')}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
                backgroundColor: const Color(0xFFF1F5F9),
                onPressed: () => _addQuick(tl),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: _confirm,
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.actionPrimary),
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
