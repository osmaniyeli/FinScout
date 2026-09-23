// lib/features/goals/widgets/goal_card_tile.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../models/financial_goal.dart';

class GoalCardTile extends StatelessWidget {
  final FinancialGoal goal;
  final VoidCallback? onTap;
  final VoidCallback? onAddContribution;

  const GoalCardTile({
    Key? key,
    required this.goal,
    this.onTap,
    this.onAddContribution,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeColor = goal.category.themeColor;
    final progress = goal.progressPercentage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: İkon Rozeti + Başlık + Kalan Ay Rozeti
            Row(
              children: [
                // Renkli İkon Rozeti (Squircle)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    goal.category.iconData,
                    color: themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Başlık ve Alt Kategori
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            goal.category.displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (goal.subType != null ||
                              goal.brandModel != null) ...[
                            const Text(' • ',
                                style: TextStyle(color: AppColors.textMuted)),
                            Expanded(
                              child: Text(
                                goal.subType ?? goal.brandModel ?? '',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: themeColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Kalan Süre Rozeti
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    goal.isCompleted
                        ? 'Tamamlandı'
                        : '${goal.monthsRemaining} ay kaldı',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: goal.isCompleted
                          ? AppColors.incomeGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Tutar Bilgisi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: CurrencyNormalizer.formatCents(
                            goal.currentSavedCents),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text: ' / ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextSpan(
                        text: CurrencyNormalizer.formatCents(
                            goal.targetAmountCents),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '%${progress.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: themeColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // İlerleme Çubuğu (Progress Bar)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              ),
            ),

            const SizedBox(height: 12),

            // Alt Satır: Aylık Tasarruf Hedefi & Birikim Ekle Butonu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!goal.isCompleted &&
                    goal.recommendedMonthlySavingsCents > 0)
                  Text(
                    'Aylık hedef: ${CurrencyNormalizer.formatCents(goal.recommendedMonthlySavingsCents)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (onAddContribution != null && !goal.isCompleted)
                  InkWell(
                    onTap: onAddContribution,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+ Birikim Ekle',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
