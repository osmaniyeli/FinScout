// lib/core/widgets/onboarding_tour/accessible_tour_card.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart' show AppRadius;
import 'tour_step.dart';

/// Stil C — erişilebilir "Bu ekranda" kartı: TalkBack (ekran okuyucu) açıkken spotlight/balon
/// yerine gösterilir (bkz. karar K28). Konuma dayalı overlay'ler ekran okuyucu kullanıcılar için
/// anlamsız olduğundan, turun TÜM adımları burada tek, animasyonsuz, kaydırılabilir bir listede
/// sırayla verilir — her adım kendi başlığıyla (Semantics header) ayrı bir odak durağıdır, TalkBack
/// kullanıcısı parmağını kaydırarak (swipe) adım adım ilerler.
class AccessibleTourCard extends StatelessWidget {
  final List<TourStep> steps;

  /// Verilmezse [Navigator.pop] kullanılır (bu widget tam ekran bir route olarak açıldığında).
  final VoidCallback? onClose;

  const AccessibleTourCard({super.key, required this.steps, this.onClose});

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Uygulamada bu ekranda neler var',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        leading: IconButton(
          key: const Key('tour_skip_button'),
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          tooltip: 'Atla',
          onPressed: () => _close(context),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: steps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final step = steps[index];
            return Semantics(
              header: true,
              label: 'Adım ${index + 1} / ${steps.length}: ${step.title}',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.actionPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.description,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('tour_finish_button'),
            onPressed: () => _close(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.actionPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: const Text(
              'Anladım',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
