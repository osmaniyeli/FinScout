// lib/core/widgets/fintech/security_auth_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../services/security_auth_service.dart';

/// PIN belirleme / doğrulama / değiştirme alt sayfası.
/// Telefonun sistem klavyesini kullanır (özel çizilmiş dairesel tuş takımı
/// 2026-09-28'de kaldırıldı — bkz. app_lock_screen.dart).
class SecurityAuthSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSuccess;
  final ValueChanged<String>? onPinEntered;
  final bool isSettingNewPin;

  const SecurityAuthSheet({
    super.key,
    this.title = 'FinScout Güvenlik Doğrulaması',
    this.subtitle =
        'Lütfen 4 haneli PIN kodunuzu girin.',
    required this.onSuccess,
    this.onPinEntered,
    this.isSettingNewPin = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    String title = 'FinScout Güvenlik Doğrulaması',
    String subtitle =
        'Lütfen 4 haneli PIN kodunuzu girin.',
    bool isSettingNewPin = false,
    ValueChanged<String>? onPinEntered,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SecurityAuthSheet(
        title: title,
        subtitle: subtitle,
        isSettingNewPin: isSettingNewPin,
        onPinEntered: onPinEntered,
        onSuccess: () {
          Navigator.of(ctx).pop(true);
        },
      ),
    );
  }

  @override
  State<SecurityAuthSheet> createState() => _SecurityAuthSheetState();
}

class _SecurityAuthSheetState extends State<SecurityAuthSheet> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    if (value.length == 4 && !_isVerifying) {
      _verifyEnteredPin(value);
    }
  }

  Future<void> _verifyEnteredPin(String pin) async {
    setState(() => _isVerifying = true);

    if (widget.isSettingNewPin) {
      await SecurityAuthService.instance.setPin(pin);
      if (mounted) {
        if (widget.onPinEntered != null) {
          widget.onPinEntered!(pin);
        }
        widget.onSuccess();
      }
      return;
    }

    final isValid = await SecurityAuthService.instance.verifyPin(pin);
    if (!mounted) return;

    if (isValid) {
      if (widget.onPinEntered != null) {
        widget.onPinEntered!(pin);
      }
      widget.onSuccess();
      return;
    }

    HapticFeedback.heavyImpact();
    _pinController.clear();
    setState(() {
      _isVerifying = false;
      _errorMessage = SecurityAuthService.instance.isLockedOut
          ? 'Çok fazla hatalı deneme! Lütfen ${SecurityAuthService.instance.remainingLockoutSeconds} saniye bekleyin.'
          : 'Hatalı PIN kodu! Kalan deneme: ${5 - SecurityAuthService.instance.failedAttempts}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // Kilit ikonu
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  widget.isSettingNewPin
                      ? Icons.lock_outline_rounded
                      : Icons.security_rounded,
                  color: const Color(0xFF10B981),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),

            // PIN girişi: sistem klavyesi
            SizedBox(
              width: 220,
              child: TextField(
                controller: _pinController,
                focusNode: _pinFocusNode,
                autofocus: true,
                enabled: !_isVerifying,
                onChanged: _onPinChanged,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: true,
                obscuringCharacter: '●',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 16,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                  ),
                ),
              ),
            ),

            if (_isVerifying) ...[
              const SizedBox(height: 14),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.expenseRed,
                ),
              ),
            ],

            const SizedBox(height: 20),

            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'İptal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
