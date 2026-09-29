// lib/core/widgets/onboarding_tour/spotlight_tour_overlay.dart

import 'package:flutter/material.dart';
import 'tour_bubble_content.dart';
import 'tour_step.dart';

/// Stil A — "ışıklı delik" (spotlight): ekranın geri kalanı koyu bir overlay ile kaplanır,
/// vurgulanan öğenin etrafında bir "delik" açılır, yanında kısa bir açıklama balonu gösterilir.
/// Ana sayfa (Dashboard) adımlarında kullanılır (bkz. karar K28).
class SpotlightTourOverlay extends StatelessWidget {
  final TourStep step;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const SpotlightTourOverlay({
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
          // 1. Karartma + delik (görsel; hedefe dokunulmaz — tur sırasında altındaki ekranla
          // etkileşim kasıtlı olarak engellenir).
          Positioned.fill(
            child: CustomPaint(painter: _SpotlightPainter(rect: rect)),
          ),
          // 2. Karartılmış alana dokunuşları yutar (arkadaki ekran tur sırasında tetiklenmesin).
          // AbsorbPointer, altındaki widget'lara işaretçi olaylarının geçmesini engeller; sahte bir
          // "boş" onTap geri çağırması gerektirmez (bkz. verify_parsers.ps1 "ölü buton" denetimi).
          const Positioned.fill(
            child: AbsorbPointer(child: SizedBox.expand()),
          ),
          // 3. Açıklama balonu, hedefin altına ya da (sığmazsa) üstüne yerleştirilir.
          if (rect != null) _buildBubble(context, rect, screenSize),
        ],
      ),
    );
  }

  Widget _buildBubble(BuildContext context, Rect rect, Size screenSize) {
    final bubbleWidth = (screenSize.width - 32).clamp(200.0, 300.0);
    final showBelow = rect.bottom + 170 < screenSize.height;
    // Üst sınır çok küçük ekranda (ya da geçerli bir boyut henüz yoksa) alt sınırın altına
    // düşebilir; clamp(lower, upper) lower > upper olduğunda ArgumentError fırlatır — bu yüzden
    // üst sınır önce en az alt sınır kadar olacak şekilde kendi içinde sıkıştırılır.
    const minLeft = 16.0;
    final maxLeft = (screenSize.width - bubbleWidth - 16).clamp(minLeft, double.infinity);
    final left = (rect.center.dx - bubbleWidth / 2).clamp(minLeft, maxLeft);

    return Positioned(
      top: showBelow ? rect.bottom + 16 : null,
      bottom: showBelow ? null : screenSize.height - rect.top + 16,
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

/// Tam ekranı koyu renkle kaplar, [rect] etrafında yuvarlatılmış köşeli bir "delik" bırakır.
class _SpotlightPainter extends CustomPainter {
  final Rect? rect;

  static const double _holeRadius = 16;

  const _SpotlightPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = const Color(0xCC0F172A);
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (rect == null) {
      canvas.drawPath(screenPath, overlayPaint);
      return;
    }

    final holeRRect =
        RRect.fromRectAndRadius(rect!, const Radius.circular(_holeRadius));
    final holePath = Path()..addRRect(holeRRect);
    final combined =
        Path.combine(PathOperation.difference, screenPath, holePath);
    canvas.drawPath(combined, overlayPaint);

    canvas.drawRRect(
      holeRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
