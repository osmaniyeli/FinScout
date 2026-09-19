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
    this.backgroundColor = const Color(0xFF0C0E14), // Shakuro Pitch Black
    this.activeIndicatorColor = const Color(0xFF2563EB), // Neon Blue Pill
    this.activeContentColor = Colors.white,
    this.inactiveColor = const Color(0xFF94A3B8), // Muted Slate
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ekranın altından 14dp yukarıda yüzer; yatayda 16dp marj
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: activeIndicatorColor.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                    borderRadius: BorderRadius.circular(22),
                    splashColor: activeIndicatorColor.withOpacity(0.2),
                    highlightColor: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? activeIndicatorColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: activeIndicatorColor.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              item.icon,
                              size: 20,
                              color: isSelected ? activeContentColor : inactiveColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? activeContentColor : inactiveColor,
                              letterSpacing: isSelected ? 0.3 : 0.0,
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
