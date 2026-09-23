// lib/core/widgets/in_app_notification_sheet.dart

import 'package:flutter/material.dart';

/// Referans Görseller:
/// 1. "Examples of branded in-app notifications" (Better Sleep tarzı yüzen kart)
/// 2. "Examples of in-app notifications" (Tip 2/3/4: Ekranın %25'ini kaplayan alt/orta modal)
///
/// Tasarım Prensipleri:
/// - Ekran yüksekliğinin kesinlikle %25'ini (veya en fazla %28'ini) geçmez.
/// - Sayfa akışını aşağı itmez; ekranın üstünde yüzen (`floating overlay`) bir karttır.
/// - Yukarıdan aşağıya kaydırılarak (`drag down to dismiss`) anında kapatılabilir.
/// - Şık elektrikli araç tasarruf ikonu, yüksek kontrastlı başlık, net karşılaştırma metni,
///   beyaz süper-elips pill butonu ("Tasarrufu Hesapla") ve "Şimdilik Değil" kapatma linki içerir.
class InAppNotificationSheet extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;
  final String dismissLabel;
  final VoidCallback? onActionTap;
  final VoidCallback? onDismiss;

  const InAppNotificationSheet({
    Key? key,
    this.title = 'Elektrikli Araç ile %70 Bakım Tasarrufu!',
    this.message =
        'Dizel ve benzinli araçlardaki motor yağı, triger, buji ve filtre masrafları elektrikli araçlarda yoktur. Ev/iş şarjı ile km başına maliyetiniz %70-80 daha ekonomiktir.',
    this.actionLabel = 'Tasarrufu Hesapla',
    this.dismissLabel = 'Şimdilik Değil',
    this.onActionTap,
    this.onDismiss,
  }) : super(key: key);

  /// Kolayca her ekrandan yüzen overlay olarak çağırmak için statik metod
  static void show(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onActionTap,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => InAppNotificationSheet(
        title: title ?? 'Elektrikli Araç ile %70 Bakım Tasarrufu!',
        message: message ??
            'Dizel ve benzinli araçlardaki motor yağı, triger, buji ve filtre masrafları elektrikli araçlarda yoktur. Ev/iş şarjı ile km başına maliyetiniz %70-80 daha ekonomiktir.',
        onActionTap: onActionTap,
      ),
    );
  }

  @override
  State<InAppNotificationSheet> createState() => _InAppNotificationSheetState();
}

class _InAppNotificationSheetState extends State<InAppNotificationSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // KURAL: Ekranın kesinlikle %25 civarında alan kaplaması
    final maxHeight = screenHeight * 0.26;

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          // Aşağı kaydırınca kapatma
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            _dismiss();
          }
        },
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          decoration: BoxDecoration(
            // Better Sleep referansındaki gibi derin koyu lacivert/mor şık zemin
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle (Yukarıdan aşağıya kaydırma çekme çubuğu)
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 2. İçerik Satırı: İkon + Başlık ve Açıklama
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glow Araç & Şarj Rozeti
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D084), Color(0xFF0052FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF00D084).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.electric_car_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Başlık ve Açıklama
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                widget.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3. Aksiyon Butonları (Better Sleep tarzı: Beyaz Pill Buton + Şimdilik Değil)
              Row(
                children: [
                  // Dismiss Metin Butonu
                  InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Text(
                        widget.dismissLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // Beyaz Süper-Elips Buton
                  InkWell(
                    onTap: () {
                      _dismiss();
                      widget.onActionTap?.call();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.actionLabel,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF0F172A),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
