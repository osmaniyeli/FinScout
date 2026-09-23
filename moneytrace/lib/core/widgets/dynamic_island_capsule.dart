// lib/core/widgets/dynamic_island_capsule.dart

import 'package:flutter/material.dart';

/// Shakuro "Inspired" & iOS Dynamic Island Yüzen Kapsül Bildirimi
///
/// Tasarım Prensipleri:
/// 1. Ekran içeriğini aşağı itmez; ekranın üstünde (Dynamic Island / Notch hizasında) yüzer (Floating Overlay).
/// 2. Kapalı modda (Collapsed): 38px yükseklikte ultra şık pitch-black hap kapsüldür.
/// 3. Açık modda (Expanded): Ekran yüksekliğinin maksimum %20 - %25'ini kaplar.
/// 4. Kapatma Hareketi: Yukarı veya aşağı hızlıca kaydırılarak (Swipe/Drag to Dismiss) kapanır.
/// 5. Shakuro Inspired görsel dili: Pitch-black zemin (#0B0B0E), ince cam parlama konturu,
///    minimalist tipografi, elektrik yeşili/neon mavi mikro rozetler.
class DynamicIslandCapsule extends StatefulWidget {
  final String title;
  final String message;
  final String? comparisonHighlight;
  final VoidCallback? onDismissed;
  final VoidCallback? onActionTap;
  final bool initialExpanded;

  const DynamicIslandCapsule({
    Key? key,
    this.title = 'Elektrikli Araç Bakım & Yakıt Avantajı',
    this.message =
        'Dizel veya benzinli araçlarda motor yağı, triger, buji, egzoz ve filtre gibi ağır periyodik bakım masrafları bulunurken; elektrikli araçlarda periyodik bakım maliyeti %60-70 daha düşüktür. Evden/işten şarj ile km başına yakıt maliyeti %70-80 daha ekonomiktir.',
    this.comparisonHighlight =
        'Yıllık 20.000 km kullanımda net ₺45.000 - ₺60.000 tasarruf.',
    this.onDismissed,
    this.onActionTap,
    this.initialExpanded = false,
  }) : super(key: key);

  @override
  State<DynamicIslandCapsule> createState() => _DynamicIslandCapsuleState();
}

class _DynamicIslandCapsuleState extends State<DynamicIslandCapsule>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    if (_isExpanded) {
      _animController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  void _dismiss() {
    setState(() {
      _isVisible = false;
    });
    widget.onDismissed?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final maxExpandedHeight = screenHeight * 0.24; // Ekranın max %24-25'i

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            // Yukarı veya aşağı hızlı kaydırma ile kapatma
            if (details.primaryVelocity != null &&
                (details.primaryVelocity! > 250 ||
                    details.primaryVelocity! < -250)) {
              if (_isExpanded) {
                _toggleExpand();
              } else {
                _dismiss();
              }
            }
          },
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final double currentHeight = Tween<double>(
                begin: 42.0,
                end: maxExpandedHeight,
              ).evaluate(_expandAnimation);

              return Container(
                width: double.infinity,
                height: currentHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0E14).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(_isExpanded ? 24 : 26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: const Color(0xFF00D084).withValues(alpha: 0.12),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _isExpanded
                    ? _buildExpandedContent()
                    : _buildCollapsedCapsule(),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Kapalı Durum: Shakuro / Dynamic Island Hap Kapsülü
  Widget _buildCollapsedCapsule() {
    return InkWell(
      onTap: _toggleExpand,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Sol İkon + Mini Rozet
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D084),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Color(0xFF064E3B),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  '⚡ EV Tasarruf:',
                  style: TextStyle(
                    color: Color(0xFF00D084),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '%70 Daha Düşük Bakım',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Sağ Açma Oku ve Kapatma Butonu
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'İncele',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Açık Durum: Shakuro Inspired Zengin Bilgi Kapsülü (Max %25 Alan)
  Widget _buildExpandedContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Kaydırma Çubuğu (Drag Handle) & Kapat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Shakuro Stili Mini Başlık Rozeti
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D084).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00D084).withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.electric_car_rounded,
                              color: Color(0xFF00D084), size: 12),
                          SizedBox(width: 4),
                          Text(
                            'AKILLI ENERJİ NÜANSI',
                            style: TextStyle(
                              color: Color(0xFF00D084),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Drag Pill Handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Kapatma İkonu
                GestureDetector(
                  onTap: _toggleExpand,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Başlık
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),

            // Açıklama Metni (Scrollable if needed inside the 24% constraint)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 11.5,
                        height: 1.38,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (widget.comparisonHighlight != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0052FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                const Color(0xFF0052FF).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.savings_outlined,
                                color: Color(0xFF60A5FA), size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.comparisonHighlight!,
                                style: const TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Alt Kısım: Shakuro Tarzı Pill Buton ve Sürükle Kapat Bilgisi
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.swipe_up_rounded,
                      size: 13,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kaydırarak kapatın',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    _toggleExpand();
                    widget.onActionTap?.call();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D084),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D084).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Hesapla & Karşılaştır',
                      style: TextStyle(
                        color: Color(0xFF064E3B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
