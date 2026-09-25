// lib/core/widgets/fade_slide_in.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// Liste öğeleri için hafif giriş: ilk kurulumda 8 px aşağıdan yukarı kayarak belirir.
///
/// Yalnız bir kez oynar (veri yenilenince ya da sekmeye dönülünce tekrar etmez).
/// [index] ile küçük bir kademe (stagger) verilir; ilk birkaç satırdan sonrası beklemez.
/// "Animasyonları kaldır" açıksa öğe doğrudan gösterilir.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppMotion.short,
  });

  final Widget child;
  final int index;
  final Duration duration;

  static const Duration _staggerStep = Duration(milliseconds: 30);
  static const int _maxStaggeredItems = 6;
  static const double _offsetPx = 8;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1.0;
      return;
    }
    final steps = widget.index.clamp(0, FadeSlideIn._maxStaggeredItems);
    if (steps == 0) {
      _controller.forward();
    } else {
      _delay = Timer(FadeSlideIn._staggerStep * steps, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curve.value) * FadeSlideIn._offsetPx),
          child: child,
        ),
      ),
    );
  }
}
