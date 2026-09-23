// lib/core/widgets/daily_streak_modal.dart

import 'package:flutter/material.dart';

/// Referans Video: document_5868465651932210343.mp4
/// "Daily Streak Animation"
///
/// Mantık:
/// 1. Kullanıcı bütçe veya harcama girdiğinde finansal disiplin serisi kutlaması.
/// 2. Canlı alev ikonu ve 29 -> 30 gün artış animasyonu.
/// 3. Haftalık gün baloncukları (Pzt, Sal, Çar, Per, Cum, Cmt, Paz).
/// 4. "Seriyi Paylaş" ve "Devam Et" butonları.
class DailyStreakModal extends StatefulWidget {
  final int streakDays;
  final VoidCallback? onContinue;
  final VoidCallback? onShare;

  const DailyStreakModal({
    Key? key,
    this.streakDays = 30,
    this.onContinue,
    this.onShare,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    int currentStreak = 30,
    VoidCallback? onContinue,
    VoidCallback? onShare,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyStreakModal(
        streakDays: currentStreak,
        onContinue: onContinue,
        onShare: onShare,
      ),
    );
  }

  @override
  State<DailyStreakModal> createState() => _DailyStreakModalState();
}

class _DailyStreakModalState extends State<DailyStreakModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<int> _streakCountAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _streakCountAnimation = IntTween(
      begin: (widget.streakDays - 1).clamp(1, 999),
      end: widget.streakDays,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEA580C), Color(0xFFC2410C)], // Canlı alev tonu
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alev İkonu
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🔥',
                    style: TextStyle(fontSize: 44),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gün Sayacı (29 -> 30)
            AnimatedBuilder(
              animation: _streakCountAnimation,
              builder: (context, child) {
                return Text(
                  '${_streakCountAnimation.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'GÜNLÜK TASARRUF SERİSİ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 18),

            // Haftalık Noktalar (Pzt - Paz)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDayBubble('Pzt', true),
                _buildDayBubble('Sal', true),
                _buildDayBubble('Çar', true),
                _buildDayBubble('Per', true),
                _buildDayBubble('Cum', true),
                _buildDayBubble('Cmt', true),
                _buildDayBubble('Paz', true),
              ],
            ),
            const SizedBox(height: 24),

            // Buton 1: Paylaş
            InkWell(
              onTap: widget.onShare,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'BAŞARINI PAYLAŞ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Buton 2: Devam Et
            InkWell(
              onTap: widget.onContinue ?? () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'DEVAM ET',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBubble(String label, bool isDone) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDone ? Colors.white : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? const Icon(
                  Icons.check_rounded,
                  color: Color(0xFFEA580C),
                  size: 14,
                )
              : null,
        ),
      ],
    );
  }
}
