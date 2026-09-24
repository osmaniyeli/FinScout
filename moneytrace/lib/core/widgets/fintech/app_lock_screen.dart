// lib/core/widgets/fintech/app_lock_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/security_auth_service.dart';
import '../../services/user_profile_service.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({
    Key? key,
    required this.onUnlocked,
  }) : super(key: key);

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _enteredDigits = [];
  bool _isVerifying = false;
  String? _errorMessage;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_enteredDigits.length >= 4 || _isVerifying) return;

    setState(() {
      _errorMessage = null;
      _enteredDigits.add(digit);
    });

    if (_enteredDigits.length == 4) {
      _verifyPin();
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

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    final pin = _enteredDigits.join();

    final isValid = await SecurityAuthService.instance.verifyPin(pin);
    if (isValid) {
      if (mounted) {
        widget.onUnlocked();
      }
    } else {
      if (mounted) {
        _shakeController.forward(from: 0.0);
        setState(() {
          _isVerifying = false;
          _enteredDigits.clear();
          _errorMessage = SecurityAuthService.instance.isLockedOut
              ? 'Çok fazla hatalı deneme! Lütfen ${SecurityAuthService.instance.remainingLockoutSeconds} saniye bekleyin.'
              : 'Hatalı PIN kodu! Kalan deneme: ${5 - SecurityAuthService.instance.failedAttempts}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = UserProfileService.instance.profile?.name ?? 'Kullanıcı';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Kilit ikonu
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Color(0xFF10B981),
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Başlık ve Selamlama
            Text(
              'Tekrar Hoş Geldiniz, $userName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Uygulama kilidi açık',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Devam etmek için 4 haneli PIN kodunuzu girin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),

            const SizedBox(height: 28),

            // 4 PIN Noktası (Animasyonlu ve Titreşimli)
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                      _shakeAnimation.value * (_enteredDigits.isEmpty ? 1 : -1),
                      0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredDigits.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? const Color(0xFF10B981)
                          : const Color(0xFF334155),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                      border: Border.all(
                        color: isFilled
                            ? const Color(0xFF34D399)
                            : const Color(0xFF475569),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Hata Mesajı
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF87171),
                  ),
                ),
              ),
            ],

            const Spacer(flex: 3),

            // 3x4 Sayısal Tuş Takımı
            _buildKeypad(),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildKeypadRow(['1', '2', '3']),
          const SizedBox(height: 14),
          _buildKeypadRow(['4', '5', '6']),
          const SizedBox(height: 14),
          _buildKeypadRow(['7', '8', '9']),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Sol alt köşe: boşluk
              const SizedBox(width: 72, height: 72),

              // 0 Rakamı
              _buildDigitButton('0'),

              // Sağ alt köşe: Silme (Backspace)
              _buildActionButton(
                icon: Icons.backspace_outlined,
                color: Colors.white70,
                onTap: _onBackspacePressed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return InkWell(
      onTap: _isVerifying ? null : () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Text(
            digit,
            style: AppTheme.numericStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isVerifying ? null : onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
