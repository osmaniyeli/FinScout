// lib/core/widgets/onboarding_tour/balloon_tour_overlay.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'tour_bubble_content.dart';
import 'tour_step.dart';

/// Stil B — "hafif balon": yalnız hedef öğenin yanında küçük, hafif bir tooltip/balon gösterilir;
/// tam ekran karartma YOKTUR (bkz. karar K28). Ana sayfa dışındaki ekranlarda (ör. alt gezinme
/// sekmeleri) kullanılır. Hedefin etrafına ince bir vurgu çerçevesi çizilir.
class BalloonTourOverlay extends StatelessWidget {
  final TourStep step;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const BalloonTourOverlay({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  Rect? _targetRect() {
    final ctx = step.targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    // hasSize kontrolü: hedef ağaca eklendi ama henüz layout almadıysa (ör. aynı karede kurulan
    // bir widget) localToGlobal/size erişimi çöker; bu durumda sessizce "hedef yok" davranılır.
    if (box == null || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(step.highlightPadding);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final rect = _targetRect();

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Tam ekran karartma yok; yalnız arkadaki ekranla kazara etkileşimi engelleyen
          // görünmez bir katman (tur sırasında altındaki sekmeye dokunulmasın). AbsorbPointer
          // sahte bir "boş" onTap geri çağırması gerektirmeden işaretçi olaylarını yutar
          // (bkz. verify_parsers.ps1 "ölü buton" denetimi).
          const Positioned.fill(
            child: AbsorbPointer(child: SizedBox.expand()),
          ),
          if (rect != null)
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.actionPrimary, width: 2),
                  ),
                ),
              ),
            ),
          if (rect != null) _buildBubble(context, rect, screenSize),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, Rect rect, Size screenSize) {
    final bubbleWidth = (screenSize.width - 32).clamp(200.0, 300.0);
    final showAbove = rect.top - 170 > 0;
    // Üst sınır çok küçük ekranda alt sınırın altına düşebilir; clamp(lower, upper) lower > upper
    // olduğunda ArgumentError fırlatır — üst sınır önce en az alt sınır kadar sıkıştırılır.
    const minLeft = 16.0;
    final maxLeft = (screenSize.width - bubbleWidth - 16).clamp(minLeft, double.infinity);
    final left = (rect.center.dx - bubbleWidth / 2).clamp(minLeft, maxLeft);

    return Positioned(
      top: showAbove ? null : rect.bottom + 12,
      bottom: showAbove ? screenSize.height - rect.top + 12 : null,
      left: left,
      width: bubbleWidth,
      child: TourBubbleContent(
        title: step.title,
        description: step.description,
        stepNumber: stepNumber,
        totalSteps: totalSteps,
        onNext: onNext,
        onSkip: onSkip,
      ),
    );
  }
}
