// lib/core/widgets/morphing_segmented_bar.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../layout/adaptive.dart' show Breakpoints;
import '../theme/app_colors.dart';

/// Video Micro-Interaction & Shakuro Inspired: Morflayan Kayan Segment Bar
/// Süper-elips hap (pill) yapısında, yay animasyonlu (spring physics), haptik titreşimli
/// ve sıfır layout-shift ile pürüzsüz sekme geçiş kontrolü.
class MorphingSegmentedBar extends StatefulWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? activePillColor;
  final Color? activeTextColor;
  final Color? inactiveTextColor;
  final Color? backgroundColor;
  final double height;
  final EdgeInsetsGeometry padding;

  const MorphingSegmentedBar({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    this.activePillColor,
    this.activeTextColor,
    this.inactiveTextColor,
    this.backgroundColor,
    this.height = 42,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  State<MorphingSegmentedBar> createState() => _MorphingSegmentedBarState();
}

class _MorphingSegmentedBarState extends State<MorphingSegmentedBar> {
  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activePillColor ?? AppColors.actionPrimary;
    final bgColor = widget.backgroundColor ?? const Color(0xFFF1F5F9);
    final activeText = widget.activeTextColor ?? Colors.white;
    final inactiveText = widget.inactiveTextColor ?? AppColors.textSecondary;

    // Büyük yazı boyutunda (erişilebilirlik) çubuk yazıyla birlikte uzar; 1.0'da yükseklik aynı.
    final scaledTextHeight =
        MediaQuery.textScalerOf(context).scale(12.5) * 1.35 + 8 + 2;
    final barHeight = math.max(widget.height, scaledTextHeight);

    return Padding(
      padding: widget.padding,
      // Tablet/yatay ekranda çubuk okunabilir genişlikte ortalanır (segmentler 300 dp'lik haplara dönüşmez)
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Breakpoints.readable),
          child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final segmentWidth = (totalWidth - 8) / widget.segments.length;

          return Container(
            height: barHeight,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(barHeight / 2 + 4),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                // Kayan Morf Eden Aktif Hap (Sliding Indicator)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubicEmphasized,
                  left: widget.selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sekme Butonları ve Metinleri
                Row(
                  children: List.generate(widget.segments.length, (index) {
                    final isSelected = widget.selectedIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSelected(index);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected ? activeText : inactiveText,
                              letterSpacing: 0.2,
                            ),
                            child: Text(
                              widget.segments[index],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
          ),
        ),
      ),
    );
  }
}
