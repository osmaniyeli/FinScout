// lib/core/widgets/compact_smart_insight_banner.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CompactSmartInsightBanner extends StatefulWidget {
  final String title;
  final String message;
  final String? secondaryDetail;
  final VoidCallback? onDismissed;
  final VoidCallback? onActionTap;

  const CompactSmartInsightBanner({
    Key? key,
    this.title = 'Akıllı Tasarruf: Elektrikli Araç Avantajı',
    this.message =
        'Dizel veya benzinli araçlarda motor yağı, triger, buji, egzoz ve filtre gibi ağır bakım masrafları varken; elektrikli araçlarda periyodik bakım maliyeti %60-70 daha düşüktür. Evden/işten şarj ile km başına yakıt tasarrufu %70-80 daha ekonomiktir.',
    this.secondaryDetail,
    this.onDismissed,
    this.onActionTap,
  }) : super(key: key);

  @override
  State<CompactSmartInsightBanner> createState() =>
      _CompactSmartInsightBannerState();
}

class _CompactSmartInsightBannerState extends State<CompactSmartInsightBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
        widget.onDismissed?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    // Ekranın en fazla %25'ini kaplama kuralı
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.25;

    return SizeTransition(
      sizeFactor: _scaleAnimation,
      axisAlignment: -1.0,
      child: Dismissible(
        key: const Key('compact_smart_insight_banner'),
        direction: DismissDirection.down,
        onDismissed: (_) => _dismiss(),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2038), Color(0xFF0A1424)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF00D084).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D084).withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Yukarıdan aşağıya kaydırma çekme çubuğu (Drag Handle)
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // İkon rozeti
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D084), Color(0xFF0052FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00D084).withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.electric_car_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Başlık ve metin içeriği
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _dismiss,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (widget.secondaryDetail != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.secondaryDetail!,
                                  style: const TextStyle(
                                    color: Color(0xFF00D084),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Alt aksiyon / Kaydırma ipucu
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Aşağı kaydırarak kapatabilirsiniz',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (widget.onActionTap != null)
                          GestureDetector(
                            onTap: widget.onActionTap,
                            child: const Text(
                              'Hesapla / Detay →',
                              style: TextStyle(
                                color: Color(0xFF00D084),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
