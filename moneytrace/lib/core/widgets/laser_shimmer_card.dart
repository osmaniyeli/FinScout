// lib/core/widgets/laser_shimmer_card.dart

import 'package:flutter/material.dart';

/// Video & Shakuro Crystal Dark Aesthetic: Laser Shimmer Card
/// Lüks FinTech kartları, VIP hedefler ve dinamik izci kartları için
/// kenar ve yüzeyden pürüzsüzce kayan kristal lazer ışıltısı efekti.
class LaserShimmerCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color backgroundColor;
  final Color shimmerColor;
  final Color borderColor;
  final bool enableShimmer;
  final VoidCallback? onTap;

  const LaserShimmerCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 22,
    this.backgroundColor = const Color(0xFF0F172A),
    this.shimmerColor = const Color(0xFF38BDF8),
    this.borderColor = const Color(0xFF334155),
    this.enableShimmer = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<LaserShimmerCard> createState() => _LaserShimmerCardState();
}

class _LaserShimmerCardState extends State<LaserShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      clipBehavior: Clip.antiAlias,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      cardContent = InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: cardContent,
      );
    }

    if (!widget.enableShimmer) {
      return Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: widget.borderColor, width: 1),
        ),
        child: cardContent,
      );
    }

    return Container(
      margin: widget.margin,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _LaserBorderPainter(
              progress: _controller.value,
              shimmerColor: widget.shimmerColor,
              baseBorderColor: widget.borderColor,
              borderRadius: widget.borderRadius,
            ),
            child: cardContent,
          );
        },
      ),
    );
  }
}

class _LaserBorderPainter extends CustomPainter {
  final double progress;
  final Color shimmerColor;
  final Color baseBorderColor;
  final double borderRadius;

  _LaserBorderPainter({
    required this.progress,
    required this.shimmerColor,
    required this.baseBorderColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Temel Çerçeve Çizgisi
    final basePaint = Paint()
      ..color = baseBorderColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, basePaint);

    // 2. Kayan Lazer Işıltısı Gradient
    final double sweepPosition = progress * 2.0 - 0.5; // -0.5 -> 1.5
    final shimmerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [
          (sweepPosition - 0.25).clamp(0.0, 1.0),
          sweepPosition.clamp(0.0, 1.0),
          (sweepPosition + 0.25).clamp(0.0, 1.0),
        ],
        colors: [
          Colors.transparent,
          shimmerColor.withValues(alpha: 0.85),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _LaserBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
