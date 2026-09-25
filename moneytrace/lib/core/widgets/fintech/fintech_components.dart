// lib/core/widgets/fintech/fintech_components.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
export 'sliding_overlay_card.dart';
export 'security_auth_sheet.dart';
export 'app_lock_screen.dart';

/// iBank / FinPay Standart FinTech Kartı
class FinanceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Border? border;

  const FinanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.color,
    this.onTap,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.card;
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.cardSurface,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }
    return content;
  }
}


/// İzci Finansal Asistan Bilgi Kartı (Sıcak Amber / Sade FinTech Dili)
class IzciInsightCard extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final VoidCallback? onDismiss;

  const IzciInsightCard({
    super.key,
    this.title = "İZCİ'DEN BİR NOT",
    required this.message,
    this.actionLabel,
    this.onActionTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Sıcak hafif amber
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFFB45309)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF78350F),
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onActionTap != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// iBank Tarzı Temiz Finansal İşlem Satırı
class CleanTransactionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final bool isExpense;
  final IconData icon;
  final Color? iconColor;
  final String? badgeText;
  final VoidCallback? onTap;

  const CleanTransactionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    this.icon = Icons.receipt_rounded,
    this.iconColor,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        iconColor ?? (isExpense ? AppColors.expenseRed : AppColors.incomeGreen);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            // 42x42 Squircle İkon Kutusu
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 20,
                color: effectiveColor,
              ),
            ),
            const SizedBox(width: 14),
            // Başlık & Açıklama
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badgeText != null && badgeText!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFBFDBFE), width: 0.8),
                          ),
                          child: Text(
                            badgeText!,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.actionPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Tutar
            Text(
              amount,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color:
                    isExpense ? AppColors.expenseRed : AppColors.actionPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
