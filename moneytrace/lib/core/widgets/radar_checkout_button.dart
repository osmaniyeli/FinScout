// lib/core/widgets/radar_checkout_button.dart

import 'package:flutter/material.dart';

/// Referans Video: document_5868465651932210346.mp4
/// "Payment Checkout V3" Radar & Glow Animasyonu
///
/// Mantık:
/// 1. Başlangıç: Mor/İndigo şık "Öde / Kaydet" butonu.
/// 2. Tıklandığında: Buton merkeze büzülür, etrafında dairesel radar dalgaları
///    ve mor neon nabız halkaları ("İşlem Doğrulanıyor %11 -> %68 -> %96") belirir.
/// 3. Bitiş: Parlayan yeşil onay dairesi ve "✓ İşlem Başarıyla Kaydedildi" rozeti.
class RadarCheckoutButton extends StatefulWidget {
  final String label;
  final String amountText;
  final String? idleAmountText;
  final String? verifyingAmountText;
  final String successTitle;
  final Future<void> Function()? onAction;
  final dynamic onPressed;
  final VoidCallback? onSuccess;
  final VoidCallback? onVerificationComplete;

  const RadarCheckoutButton({
    Key? key,
    this.label = 'Güvenle Kaydet',
    this.amountText = '',
    this.idleAmountText,
    this.verifyingAmountText,
    this.successTitle = 'Kayıt Başarılı',
    this.onAction,
    this.onPressed,
    this.onSuccess,
    this.onVerificationComplete,
  }) : super(key: key);

  @override
  State<RadarCheckoutButton> createState() => _RadarCheckoutButtonState();
}

enum _CheckoutPhase { idle, pulsing, verified }

class _RadarCheckoutButtonState extends State<RadarCheckoutButton>
    with TickerProviderStateMixin {
  _CheckoutPhase _phase = _CheckoutPhase.idle;
  late AnimationController _radarController;
  late AnimationController _progressController;
  String _statusText = 'İşlem Doğrulanıyor...';
  int _progressPercent = 11;

  bool get _isEnabled =>
      widget.onPressed != null ||
      widget.onAction != null ||
      (widget.onPressed == null && widget.onAction == null && widget.onVerificationComplete == null && widget.onSuccess == null);

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    if (_phase != _CheckoutPhase.idle) return;
    if (!_isEnabled) return;

    setState(() {
      _phase = _CheckoutPhase.pulsing;
      _statusText = widget.verifyingAmountText ?? 'İşlem Doğrulanıyor...';
      _progressPercent = 15;
    });

    // Simüle aşamalı doğrulama (Videodaki %11 -> %68 -> %96 hissi)
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() { _statusText = 'Güvenlik Protokolü...'; _progressPercent = 58; });

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() { _statusText = 'Güvenli Bağlantı...'; _progressPercent = 94; });

    if (widget.onPressed != null) {
      final res = (widget.onPressed as dynamic)();
      if (res is Future) await res;
    } else if (widget.onAction != null) {
      await widget.onAction!();
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (mounted) {
      setState(() {
        _phase = _CheckoutPhase.verified;
      });
      widget.onSuccess?.call();
      widget.onVerificationComplete?.call();

      // 3 saniye sonra başa dön
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          setState(() {
            _phase = _CheckoutPhase.idle;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _CheckoutPhase.idle:
        return _buildIdleButton();
      case _CheckoutPhase.pulsing:
        return _buildRadarPulse();
      case _CheckoutPhase.verified:
        return _buildSuccessCard();
    }
  }

  Widget _buildIdleButton() {
    final displayAmount = widget.idleAmountText ?? widget.amountText;
    return Opacity(
      opacity: _isEnabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: _isEnabled ? _startCheckout : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (displayAmount.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '($displayAmount)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarPulse() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Radar Daireleri
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, child) {
              final val = _radarController.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Dış radar halkası
                  Container(
                    width: 70 + (val * 30),
                    height: 70 + (val * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(1.0 - val),
                        width: 2.0,
                      ),
                    ),
                  ),
                  // İç radar merkezi
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.5),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            _statusText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '%$_progressPercent',
            style: const TextStyle(
              color: Color(0xFF8B5CF6),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF10B981),
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.successTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.amountText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.amountText,
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
