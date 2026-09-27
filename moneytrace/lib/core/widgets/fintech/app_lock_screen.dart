// lib/core/widgets/fintech/app_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/security_auth_service.dart';
import '../../services/user_profile_service.dart';

/// Uygulama açılış kilidi. Telefonun kendi sistem klavyesini kullanır
/// (özel çizilmiş dairesel tuş takımı 2026-09-28'de kaldırıldı — karmaşık
/// IntrinsicHeight/Spacer/AnimationController kombinasyonu, siyah ekranda
/// takılma hatasının olası kök nedenlerinden biriydi).
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({
    super.key,
    required this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
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
      _verifyPin(value);
    }
  }

  Future<void> _verifyPin(String pin) async {
    setState(() => _isVerifying = true);

    final isValid = await SecurityAuthService.instance.verifyPin(pin);
    if (!mounted) return;

    if (isValid) {
      widget.onUnlocked();
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
    final userName = UserProfileService.instance.profile?.name ?? 'Kullanıcı';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              ..._buildHeader(userName),
              const SizedBox(height: 32),
              _buildPinField(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Kilit ikonu, selamlama ve açıklama metni.
  List<Widget> _buildHeader(String userName) => [
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
      ];

  Widget _buildPinField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            autofillHints: const [AutofillHints.password],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 18,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
              ),
            ),
          ),
        ),
        if (_isVerifying) ...[
          const SizedBox(height: 16),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ],
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
      ],
    );
  }
}
