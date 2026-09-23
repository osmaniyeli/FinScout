// lib/core/widgets/fintech/security_auth_sheet.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../services/security_auth_service.dart';

class SecurityAuthSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSuccess;
  final ValueChanged<String>? onPinEntered;
  final bool isSettingNewPin;
  final bool allowBiometrics;

  const SecurityAuthSheet({
    Key? key,
    this.title = 'Paraİz Güvenlik Doğrulaması',
    this.subtitle =
        'Lütfen 4 haneli PIN kodunuzu girin veya biyometrik ile doğrulayın.',
    required this.onSuccess,
    this.onPinEntered,
    this.isSettingNewPin = false,
    this.allowBiometrics = true,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    String title = 'Paraİz Güvenlik Doğrulaması',
    String subtitle =
        'Lütfen 4 haneli PIN kodunuzu girin veya biyometrik ile doğrulayın.',
    bool isSettingNewPin = false,
    bool allowBiometrics = true,
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
        allowBiometrics: allowBiometrics,
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
  final List<String> _enteredDigits = [];
  bool _isVerifying = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_enteredDigits.length >= 4 || _isVerifying) return;

    setState(() {
      _errorMessage = null;
      _enteredDigits.add(digit);
    });

    if (_enteredDigits.length == 4) {
      _verifyEnteredPin();
    }
  }

  void _onBackspacePressed() {
    if (_enteredDigits.isNotEmpty && !_isVerifying) {
      setState(() {
        _errorMessage = null;
        _enteredDigits.removeLast();
      });
    }
  }

  Future<void> _verifyEnteredPin() async {
    setState(() => _isVerifying = true);
    final pin = _enteredDigits.join();

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
    if (isValid) {
      if (mounted) {
        if (widget.onPinEntered != null) {
          widget.onPinEntered!(pin);
        }
        widget.onSuccess();
      }
    } else {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _enteredDigits.clear();
          _errorMessage = SecurityAuthService.instance.isLockedOut
              ? 'Çok fazla hatalı deneme! Lütfen 30 saniye bekleyin.'
              : 'Hatalı PIN kodu! Kalan deneme: ${5 - SecurityAuthService.instance.failedAttempts}';
        });
      }
    }
  }

  Future<void> _triggerBiometricAuth(BiometricAuthType type) async {
    if (_isVerifying || !widget.allowBiometrics) return;
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final success = type == BiometricAuthType.fingerprint
        ? await SecurityAuthService.instance
            .authenticateFingerprint(reason: 'Parmak izi ile giriş yapılıyor')
        : await SecurityAuthService.instance
            .authenticateFaceId(reason: 'Yüz tanıma ile giriş yapılıyor');

    if (mounted) {
      if (success) {
        widget.onSuccess();
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Biyometrik doğrulama başarısız oldu.';
        });
      }
    }
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

          // Glowing Shield / Biometric Icon
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

          // 4 PIN Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _enteredDigits.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
                  border: Border.all(
                    color: isFilled
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
              );
            }),
          ),

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

          const SizedBox(height: 24),

          // Keypad
          _buildKeypad(),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Sol: Yüz Tanıma / Parmak İzi Butonu (yalnızca izin verildiyse)
            widget.allowBiometrics
                ? _buildSpecialKey(
                    icon: Icons.face_retouching_natural,
                    label: 'Yüz / İz',
                    onTap: () =>
                        _triggerBiometricAuth(BiometricAuthType.faceId),
                  )
                : _buildSpecialKey(
                    icon: Icons.close_rounded,
                    label: 'İptal',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
            // Orta: 0
            _buildNumberKey('0'),
            // Sağ: Backspace
            _buildSpecialKey(
              icon: Icons.backspace_outlined,
              label: 'Sil',
              onTap: _onBackspacePressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberKey(n)).toList(),
    );
  }

  Widget _buildNumberKey(String number) {
    return InkWell(
      onTap: () => _onDigitPressed(number),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 68,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 68,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF0F172A), size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
