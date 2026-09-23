// lib/core/widgets/floating_capsule_nav_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shakuro Inspired & Video 5 Floating Capsule Bottom Navigation Bar.
/// Yüzen kapsül (super-ellipse pill) formunda, neon aktif hap göstergeli,
/// yaylanma (spring) geçişli ve derin gölgeli ultra modern alt menü.
class FloatingCapsuleNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingCapsuleNavItem> items;
  final Color backgroundColor;
  final Color activeIndicatorColor;
  final Color activeContentColor;
  final Color inactiveColor;

  const FloatingCapsuleNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.backgroundColor = Colors.white,
    this.activeIndicatorColor = const Color(0xFF2563EB), // iBank FinTech Kobalt
    this.activeContentColor = Colors.white,
    this.inactiveColor = const Color(0xFF94A3B8), // Muted Slate
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(20),
                  splashColor: activeIndicatorColor.withValues(alpha: 0.12),
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      vertical: isSelected ? 8 : 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeIndicatorColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color:
                              isSelected ? activeContentColor : inactiveColor,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isSelected ? activeContentColor : inactiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class FloatingCapsuleNavItem {
  final IconData icon;
  final String label;

  const FloatingCapsuleNavItem({
    required this.icon,
    required this.label,
  });
}
