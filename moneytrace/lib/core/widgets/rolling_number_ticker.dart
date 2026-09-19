// lib/core/widgets/rolling_number_ticker.dart

import 'package:flutter/material.dart';

/// Video & FinTech Dynamic Ticker: Rolling Number Ticker
/// Finansal tutarlar (₺), yüzdeler ve birikim metrikleri değiştiğinde
/// pürüzsüz artan/azalan yay eğrili sayı animasyonu.
class RollingNumberTicker extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;

  const RollingNumberTicker({
    Key? key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 750),
    this.fractionDigits = 2,
  }) : super(key: key);

  @override
  State<RollingNumberTicker> createState() => _RollingNumberTickerState();
}

class _RollingNumberTickerState extends State<RollingNumberTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: widget.value, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant RollingNumberTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation = Tween<double>(begin: _previousValue, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double val) {
    // Türk Lirası binlik ayıracı '.' ve ondalık ayıracı ','
    final parts = val.toStringAsFixed(widget.fractionDigits).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    if (widget.fractionDigits > 0) {
      return '$intPart,${parts[1]}';
    }
    return intPart;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_formatNumber(_animation.value)}${widget.suffix}',
          style: textStyle,
        );
      },
    );
  }
}
