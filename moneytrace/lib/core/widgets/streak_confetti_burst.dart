// lib/core/widgets/streak_confetti_burst.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hedef tamamlama ve günlük streak kutlamalarında patlayan parçacık / konfeti efekti.
class StreakConfettiBurst extends StatefulWidget {
  final Widget? child;
  final bool trigger;
  final AnimationController? controller;
  final VoidCallback? onComplete;

  const StreakConfettiBurst({
    Key? key,
    this.child,
    this.trigger = false,
    this.controller,
    this.onComplete,
  }) : super(key: key);

  @override
  State<StreakConfettiBurst> createState() => _StreakConfettiBurstState();
}

class _StreakConfettiBurstState extends State<StreakConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _internalController;
  AnimationController get _controller =>
      widget.controller ?? _internalController;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _internalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.trigger ||
        (widget.controller != null && widget.controller!.isAnimating)) {
      _startBurst();
    }
    widget.controller?.addListener(_onExternalController);
  }

  void _onExternalController() {
    if (widget.controller != null &&
        widget.controller!.isAnimating &&
        _particles.isEmpty) {
      _startBurst();
    }
  }

  @override
  void didUpdateWidget(covariant StreakConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.trigger && widget.trigger) {
      _startBurst();
    }
  }

  void _startBurst() {
    _particles.clear();
    const colors = [
      Color(0xFFF59E0B), // Amber
      Color(0xFF10B981), // Emerald
      Color(0xFF3B82F6), // Blue
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Purple
      Color(0xFFF43F5E), // Rose
    ];

    for (int i = 0; i < 36; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 80.0 + (_random.nextDouble() * 160.0);
      _particles.add(_Particle(
        color: colors[i % colors.length],
        angle: angle,
        speed: speed,
        size: 5.0 + (_random.nextDouble() * 6.0),
        rotation: _random.nextDouble() * math.pi,
      ));
    }

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onExternalController);
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: progress,
            opacity: opacity,
          ),
        );
      },
    );

    if (widget.child == null) {
      return _controller.isAnimating ? canvas : const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child!,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: canvas,
            ),
          ),
      ],
    );
  }
}

class _Particle {
  final Color color;
  final double angle;
  final double speed;
  final double size;
  final double rotation;

  _Particle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double opacity;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final distance = p.speed * progress;
      final dx = center.dx + (math.cos(p.angle) * distance);
      // Yerçekimi ivmesi
      final dy = center.dy +
          (math.sin(p.angle) * distance) +
          (progress * progress * 60);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + (progress * 4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
