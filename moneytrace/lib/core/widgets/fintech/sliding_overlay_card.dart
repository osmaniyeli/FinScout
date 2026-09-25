// lib/core/widgets/fintech/sliding_overlay_card.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Frontend Joe (@frontendjoe) Pure CSS Sliding Overlay mimarisinden esinlenilmiş,
/// 60/120 FPS fizik tabanlı, çift yönlü kayar kapaklı (Sliding Overlay Dual-Card) fintech bileşeni.
///
/// 0.65s cubic-bezier (Curves.easeInOutCubic) eğrisiyle kayan renkli/degrade kapak,
/// zıt yöne kayan ve cross-fade yapan hero başlıklar ve form içeriklerini barındırır.
class SlidingOverlayCard extends StatefulWidget {
  final String primaryHeroTitle;
  final String primaryHeroSubtitle;
  final String primaryButtonText;
  final Widget primaryForm;
  final LinearGradient? primaryGradient;

  final String secondaryHeroTitle;
  final String secondaryHeroSubtitle;
  final String secondaryButtonText;
  final Widget secondaryForm;
  final LinearGradient? secondaryGradient;

  final bool isSecondary;
  final ValueChanged<bool>? onToggle;
  final double height;
  final double borderRadius;

  const SlidingOverlayCard({
    super.key,
    required this.primaryHeroTitle,
    required this.primaryHeroSubtitle,
    required this.primaryButtonText,
    required this.primaryForm,
    this.primaryGradient,
    required this.secondaryHeroTitle,
    required this.secondaryHeroSubtitle,
    required this.secondaryButtonText,
    required this.secondaryForm,
    this.secondaryGradient,
    this.isSecondary = false,
    this.onToggle,
    this.height = 220,
    this.borderRadius = 22,
  });

  @override
  State<SlidingOverlayCard> createState() => _SlidingOverlayCardState();
}

class _SlidingOverlayCardState extends State<SlidingOverlayCard>
    with SingleTickerProviderStateMixin {
  late bool _isSecondary;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _isSecondary = widget.isSecondary;
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 650), // Frontend Joe 0.65s transition
    );

    // Frontend Joe ease-in-out / cubic-bezier(0.65, 0, 0.35, 1) eğrisi
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    );

    if (_isSecondary) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant SlidingOverlayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSecondary != oldWidget.isSecondary &&
        widget.isSecondary != _isSecondary) {
      _toggleMode(widget.isSecondary, notify: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMode(bool toSecondary, {bool notify = true}) {
    setState(() {
      _isSecondary = toSecondary;
    });

    if (toSecondary) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    if (notify && widget.onToggle != null) {
      widget.onToggle!(toSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Varsayılan degrade renkleri (Birincil: Royal Blue / Lacivert, İkincil: Emerald / Orman Yeşili)
    final defaultPrimaryGradient = widget.primaryGradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        );

    final defaultSecondaryGradient = widget.secondaryGradient ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF047857), Color(0xFF064E3B)],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final halfWidth = totalWidth * 0.48; // Kapak genişliği

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: AppShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 1. SOL İÇERİK ALANI (Form 1 / Primary Form)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: totalWidth * 0.52,
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    final opacity =
                        (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: widget.primaryForm,
                      ),
                    );
                  },
                ),
              ),

              // 2. SAĞ İÇERİK ALANI (Form 2 / Secondary Form)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: totalWidth * 0.52,
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    final opacity = _fadeAnimation.value.clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: widget.secondaryForm,
                      ),
                    );
                  },
                ),
              ),

              // 3. KAYAR KAPAK (Sliding Overlay Background - Frontend Joe .card-bg)
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  // _slideAnimation.value: 0.0 (Sağda kapak) -> 1.0 (Solda kapak)
                  // Toplam kayma mesafesi: (totalWidth - halfWidth)
                  final maxOffset = totalWidth - halfWidth;
                  // Başlangıçta sağda (maxOffset), secondary modda solda (0)
                  final currentLeft = (1.0 - _slideAnimation.value) * maxOffset;

                  return Positioned(
                    left: currentLeft,
                    top: 0,
                    bottom: 0,
                    width: halfWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _isSecondary
                            ? defaultSecondaryGradient
                            : defaultPrimaryGradient,
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius - 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x28000000),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Canlı Hero Başlık (Cross-fade)
                          AnimatedCrossFade(
                            firstChild: _buildHeroContent(
                              title: widget.primaryHeroTitle,
                              subtitle: widget.primaryHeroSubtitle,
                              buttonText: widget.primaryButtonText,
                              onAction: () => _toggleMode(true),
                            ),
                            secondChild: _buildHeroContent(
                              title: widget.secondaryHeroTitle,
                              subtitle: widget.secondaryHeroSubtitle,
                              buttonText: widget.secondaryButtonText,
                              onAction: () => _toggleMode(false),
                            ),
                            crossFadeState: _isSecondary
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 320),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroContent({
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onAction,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        // Frontend Joe tarzı cam efektli şık geçiş butonu
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
