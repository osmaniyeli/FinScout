// lib/core/widgets/pulse_metric_badge.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Video 4 Radar Pulse & Shakuro Glow estetiğini kopyalayan canlı nabız rozeti.
/// Finansal hedeflerde, bakiye farklarında ve kritik uyarılarda genişleyen radar halkaları yayar.
class PulseMetricBadge extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color baseColor;
  final Color pulseColor;
  final VoidCallback? onTap;
  final bool isPositive;

  const PulseMetricBadge({
    Key? key,
    required this.label,
    required this.value,
    this.icon = Icons.insights_rounded,
    this.baseColor = const Color(0xFF0C0E14),
    this.pulseColor = const Color(0xFF10B981),
    this.onTap,
    this.isPositive = true,
  }) : super(key: key);

  @override
  State<PulseMetricBadge> createState() => _PulseMetricBadgeState();
}

class _PulseMetricBadgeState extends State<PulseMetricBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Genişleyen Radar Dalgası Animasyonu (Aura)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final val = _pulseController.value;
              final outerScale = 1.0 + (val * 0.18);
              final opacity = (1.0 - val).clamp(0.0, 1.0) * 0.45;

              return Transform.scale(
                scale: outerScale,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.pulseColor.withValues(alpha: opacity * 0.5),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: widget.pulseColor.withValues(alpha: opacity),
                      width: 1.5,
                    ),
                  ),
                  child: Opacity(
                    opacity: 0,
                    child: _buildBadgeContent(),
                  ),
                ),
              );
            },
          ),

          // Ana Yüzen Kapsül
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: widget.baseColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: widget.pulseColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: widget.pulseColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildBadgeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Yanıp Sönen Canlı Radar Noktası
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final blink =
                (math.sin(_pulseController.value * math.pi * 2) + 1) / 2;
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.pulseColor,
                boxShadow: [
                  BoxShadow(
                    color: widget.pulseColor
                        .withValues(alpha: 0.5 + (blink * 0.5)),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),

        Icon(widget.icon, size: 16, color: widget.pulseColor),
        const SizedBox(width: 6),

        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 4),

        Text(
          widget.value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: widget.pulseColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
