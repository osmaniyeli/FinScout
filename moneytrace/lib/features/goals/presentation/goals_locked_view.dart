// lib/features/goals/presentation/goals_locked_view.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';

/// Ücretsiz planda Hedefler sekmesi yerine gösterilen basit kilit/paywall kartı.
/// Gerçek GoalsScreen yalnız Premium kullanıcılara gösterilir (bkz. MainNavigationScaffold).
class GoalsLockedView extends StatelessWidget {
  const GoalsLockedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Çok kısa/yatay ekranlarda (ör. telefon yatay + büyük yazı) sabit ikon+metin yüksekliği
        // taşabilir; kaydırılabilir yaparak taşmayı önler (bkz. test/adaptive_layout_test.dart).
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        size: 36, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hedefler Premium\'da',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Birikim hedeflerini belirle, ilerlemeni izle. Bu özellik Premium planlarda açık.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => SubscriptionPlansSheet.show(context),
                      icon: const Icon(Icons.workspace_premium_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Premium\'a Geç',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.actionPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
