// lib/features/onboarding/presentation/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/security_auth_service.dart';
import '../../../core/widgets/fintech/fintech_components.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({Key? key, required this.onCompleted})
      : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _signInEmailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isSignInMode = false;

  /// Kod gönderildiyse e-posta adresi; kod adımı gösterilir.
  String? _codeSentTo;
  bool _codeIsForSignup = false;

  @override
  void initState() {
    super.initState();
    SecurityAuthService.instance.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _signInEmailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.expenseRed, content: Text(message)),
    );
  }

  Future<void> _completeRegistration() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty) {
      _showError('Lütfen adını ve soyadını gir.');
      return;
    }
    if (!AccountService.isValidEmail(email)) {
      _showError('Lütfen geçerli bir e-posta adresi gir.');
      return;
    }
    await _sendCode(email, signup: true, fullName: name);
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final profile = await AccountService.instance.signInWithGoogle();
      if (profile != null && mounted) {
        widget.onCompleted();
        return;
      }
    } on AccountException catch (e) {
      _showError(e.message);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _startEmailSignIn() async {
    final email = _signInEmailController.text.trim();
    if (!AccountService.isValidEmail(email)) {
      _showError('Lütfen geçerli bir e-posta adresi gir.');
      return;
    }
    await _sendCode(email, signup: false);
  }

  Future<void> _sendCode(String email,
      {required bool signup, String? fullName}) async {
    setState(() => _isLoading = true);
    try {
      await AccountService.instance
          .sendCode(email, createUser: signup, fullName: fullName);
      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _codeSentTo = email.toLowerCase();
        _codeIsForSignup = signup;
      });
    } on AccountException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _codeSentTo;
    final code = _codeController.text.trim();
    if (email == null) return;
    if (code.length < 6) {
      _showError('E-postana gelen kodu eksiksiz gir.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AccountService.instance.verifyCode(email, code,
          fullName: _codeIsForSignup ? _nameController.text.trim() : null);
      if (mounted) widget.onCompleted();
    } on AccountException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithBiometrics(BiometricAuthType type) async {
    setState(() => _isLoading = true);

    final success = await SecurityAuthService.instance.authenticateBiometric(
      reason: 'FinScout Parmak İzi ile Giriş',
      specificType: type,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        await _ensureProfileAndProceed();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.expenseRed,
            content: Text(
                'Biyometrik doğrulama başarısız oldu. Lütfen PIN kodunuzu deneyin.'),
          ),
        );
      }
    }
  }

  Future<void> _loginWithPin() async {
    final verified = await SecurityAuthSheet.show(
      context,
      title: 'PIN Kodu ile Giriş',
      subtitle: 'FinScout kasanıza erişmek için 4 haneli PIN kodunuzu girin.',
      isSettingNewPin: false,
    );

    if (verified == true && mounted) {
      await _ensureProfileAndProceed();
    }
  }

  Future<void> _ensureProfileAndProceed() async {
    if (!UserProfileService.instance.hasProfile) {
      if (mounted) setState(() => _isSignInMode = false);
      return;
    }
    if (mounted) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo ve Marka Başlığı
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.24),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '₺',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'FinScout',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Harcama Zekası ve Biyometrik Güvenlik',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Frontend Joe Pure CSS Sliding Overlay Dual-Card
              SlidingOverlayCard(
                height: 175,
                borderRadius: 22,
                isSecondary: _isSignInMode,
                onToggle: (val) {
                  setState(() {
                    _isSignInMode = val;
                  });
                },
                // Mod 1: Kayıt Ol (Sign Up) -> Kapak Sağda
                primaryHeroTitle: 'Zaten hesabın var mı?',
                primaryHeroSubtitle:
                    'Mevcut cüzdanına ve profiline hemen giriş yap.',
                primaryButtonText: 'GİRİŞ YAP',
                primaryGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF047857), Color(0xFF0F172A)],
                ),
                primaryForm: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            color: Color(0xFF10B981), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'KAYIT OL',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'FinScout ile bütçeni kontrol altına al.',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),

                // Mod 2: Giriş Yap (Sign In) -> Kapak Solda
                secondaryHeroTitle: 'Yeni misin?',
                secondaryHeroSubtitle:
                    'Bütçeni akıllıca yönetmek için hemen profilini oluştur.',
                secondaryButtonText: 'KAYIT OL',
                secondaryGradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF0F172A)],
                ),
                secondaryForm: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.lock_open_rounded,
                            color: Color(0xFF2563EB), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'GİRİŞ YAP',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Kayıtlı cüzdanına ve kartlarına dön.',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dinamik Form Alanı (Kayıt Ol vs Giriş Yap), kod gönderildiyse doğrulama
              if (_codeSentTo != null)
                _buildCodeStep()
              else
                AnimatedCrossFade(
                  firstChild: _buildSignUpForm(),
                  secondChild: _buildSignInForm(),
                  crossFadeState: _isSignInMode
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 320),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. KAYIT OL FORMU (Sign Up)
  // ==========================================
  Widget _buildSignUpForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesap Bilgilerinizi Belirleyin',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ekstrelerini yükledikçe bankaların ve kartların otomatik tanınır.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _googleButton(),
          _orDivider(),

          // Ad Soyad
          const Text(
            'Adınız veya Kullanıcı Adınız *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Örn: Ahmet Yılmaz',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                borderSide:
                    const BorderSide(color: Color(0xFF0052FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'E-posta Adresin *',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          _inputField(
            controller: _emailController,
            hint: 'ornek@eposta.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Güvenlik Rozeti
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Şifre yok: e-postana gelen kodla giriş yaparsın. Harcama verilerin bu cihazda kalır; hesabında yalnızca adın ve e-postan tutulur.',
                    style: TextStyle(
                        fontSize: 11.5, color: Color(0xFF15803D), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Başla Butonu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _completeRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Doğrulama Kodu Gönder',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. GİRİŞ YAP FORMU (Sign In / Biometrics / PIN)
  // ==========================================
  Widget _buildSignInForm() {
    final hasExistingProfile = UserProfileService.instance.hasProfile;
    final existingName =
        UserProfileService.instance.profile?.name ?? 'Kayıtlı Kullanıcı';

    if (!hasExistingProfile) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.mark_email_read_outlined,
                    color: Color(0xFF2563EB), size: 26),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'E-posta ile Giriş',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hesabının e-postasını gir; giriş kodunu gönderelim.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            _googleButton(),
            _orDivider(),
            _inputField(
              controller: _signInEmailController,
              hint: 'ornek@eposta.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startEmailSignIn,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Giriş Kodu Gönder',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _isSignInMode = false),
              child: const Text('Hesabın yok mu? Kayıt ol',
                  style:
                      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded,
                      color: Color(0xFF0F172A), size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tekrar Hoş Geldiniz!',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      existingName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const Text(
            'Hızlı Biyometrik veya PIN ile Giriş Yapın',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),

          // 2. Parmak İzi ile Giriş (Touch ID / Fingerprint)
          InkWell(
            onTap: () => _loginWithBiometrics(BiometricAuthType.fingerprint),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.fingerprint_rounded,
                      color: Color(0xFF2563EB), size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parmak İzi ile Giriş (Touch ID)',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E40AF)),
                        ),
                        Text(
                          'Sensöre dokunun, güvenle kasanıza erişin',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF2563EB), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. PIN Kodu ile Giriş
          InkWell(
            onTap: _loginWithPin,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.pin_rounded, color: Color(0xFF0F172A), size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '4 Haneli PIN Kodu ile Giriş',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Şifrenizi tuşlayarak giriş yapın',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF64748B), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Kilit kapalıysa doğrudan devam; açıksa yalnızca parmak izi / PIN ile
          if (!SecurityAuthService.instance.isAnySecurityActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _ensureProfileAndProceed,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Devam Et',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4285F4))),
            SizedBox(width: 10),
            Text('Google ile Devam Et',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _orDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('veya e-posta ile',
                style:
                    TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
          Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5),
        ),
      ),
    );
  }

  // ==========================================
  // 3. E-POSTA KODU DOĞRULAMA
  // ==========================================
  Widget _buildCodeStep() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'E-postanı Kontrol Et',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '$_codeSentTo adresine gönderilen kodu gir. Gelen kutunda yoksa spam klasörüne bak.',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            autofocus: true,
            maxLength: 8,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _verifyCode(),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••••',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Doğrula ve Devam Et',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _codeSentTo = null),
                child: const Text('E-postayı değiştir'),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _sendCode(_codeSentTo!,
                        signup: _codeIsForSignup,
                        fullName: _codeIsForSignup
                            ? _nameController.text.trim()
                            : null),
                child: const Text('Kodu tekrar gönder'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
