// lib/core/widgets/fade_through_indexed_stack.dart

import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// [IndexedStack] gibi tüm sekmeleri canlı tutar (durum, kaydırma konumu, yüklenen veri
/// kaybolmaz; ekranlar geçişte yeniden kurulmaz), ama sekme değişimini Material
/// "fade-through" deseniyle yapar:
///
///  * Eski sekme ilk %35'te söner (emphasized accelerate),
///  * yeni sekme kalan sürede belirir ve %96 → %100 ölçeklenir (emphasized decelerate).
///
/// Toplam süre [AppMotion.medium] (280 ms). "Animasyonları kaldır" açıksa geçiş anındadır.
/// Görünmeyen sekmelerin ticker'ları durdurulur (arka plan animasyonu CPU yakmaz).
class FadeThroughIndexedStack extends StatefulWidget {
  const FadeThroughIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = AppMotion.medium,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<FadeThroughIndexedStack> createState() =>
      _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<FadeThroughIndexedStack>
    with SingleTickerProviderStateMixin {
  // Fade-through: çıkış ve giriş üst üste binmez; aradaki boşlukta arka plan görünür.
  static const double _outEnd = 0.35;
  static const double _incomingScaleBegin = 0.96;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1.0,
  )..addStatusListener(_onStatus);

  late final Animation<double> _outOpacity = Tween<double>(begin: 1, end: 0)
      .animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, _outEnd, curve: AppMotion.exit)));

  late final Animation<double> _inOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(_outEnd, 1.0, curve: AppMotion.enter));

  late final Animation<double> _inScale =
      Tween<double>(begin: _incomingScaleBegin, end: 1).animate(CurvedAnimation(
          parent: _controller,
          curve: const Interval(_outEnd, 1.0, curve: AppMotion.enter)));

  /// Geçiş sürerken sönen sekme; geçiş yoksa null.
  int? _outgoing;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null && mounted) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(covariant FadeThroughIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.index == widget.index) return;

    final previous = oldWidget.index;
    final hasPrevious = previous >= 0 && previous < widget.children.length;
    if (!hasPrevious || AppMotion.reduceMotion(context)) {
      _outgoing = null;
      _controller.value = 1.0;
      return;
    }
    _outgoing = previous;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.index;
    final outgoing = _outgoing;

    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _buildSlot(i, isCurrent: i == current, isOutgoing: i == outgoing),
      ],
    );
  }

  /// Ağaç yapısı her durumda aynıdır (yalnız parametreler değişir) —
  /// böylece sekme ekranlarının State'i hiçbir geçişte yeniden oluşturulmaz.
  Widget _buildSlot(int i, {required bool isCurrent, required bool isOutgoing}) {
    final visible = isCurrent || isOutgoing;
    final Animation<double> opacity = isOutgoing
        ? _outOpacity
        : (isCurrent && _outgoing != null ? _inOpacity : kAlwaysCompleteAnimation);
    final Animation<double> scale = isCurrent && _outgoing != null
        ? _inScale
        : kAlwaysCompleteAnimation;

    return KeyedSubtree(
      key: ValueKey<int>(i),
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: IgnorePointer(
            ignoring: !isCurrent,
            child: ExcludeSemantics(
              excluding: !isCurrent,
              // IndexedStack gibi: görünmeyen/sönen sekme odak alamaz (açık klavye, TAB/D-pad
              // gezintisi ya da donanım klavyesi girişi gizli sekmedeki alana gitmesin).
              child: ExcludeFocus(
                excluding: !isCurrent,
                child: FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: scale,
                    child: widget.children[i],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
