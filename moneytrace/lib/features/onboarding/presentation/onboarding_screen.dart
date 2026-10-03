// lib/features/onboarding/presentation/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/layout/adaptive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/security_auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/widgets/fintech/fintech_components.dart';
import '../../../core/widgets/fintech/bank_selection_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

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

  /// Girişten/kayıttan sonra tüm başarılı akışların tek geçtiği yer: yalnız YENİ hesap
  /// oluşturulduysa (var olan hesaba giriş değil) banka seçim sheet'i gösterilir, sonra
  /// widget.onCompleted() çağrılır. AccountService.lastSignInCreatedAccount main.dart'ın
  /// _announceNewAccount'ı içinde (yani widget.onCompleted() İÇİNDE) sıfırlanır, bu yüzden
  /// burada henüz true/false doğru değerindedir (bkz. account_service.dart _saveLocalProfile).
  Future<void> _finishOnboarding() async {
    if (!mounted) return;
    if (AccountService.instance.lastSignInCreatedAccount &&
        (UserProfileService.instance.profile?.lockedInstitution == null ||
            UserProfileService.instance.profile!.lockedInstitution!.isEmpty)) {
      await BankSelectionSheet.show(context, allowSkip: true);
    }
    if (mounted) widget.onCompleted();
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
        await _finishOnboarding();
        return;
      }
      final code = AccountService.instance.lastGoogleCancelCode;
      if (profile == null && code != null && mounted) {
        // Telefonun hesap seçicisi girişi tamamlamadı (çoğunlukla imza/OAuth yapılandırması).
        // Tarayıcı yolu bu yapılandırmaya bağlı değil: kullanıcıya sun.
        // Teşhis: telefondaki uygulamanın imza SHA-1'i; Google Cloud'daki Android istemcisiyle karşılaştırılır.
        final sha1 = await AccountService.instance.appSigningSha1();
        if (!mounted) return;
        final useBrowser = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Google girişi tamamlanmadı'),
            content: SelectableText(
                'Telefonun Google hesap seçicisi girişi bitiremedi.\n\n'
                'Ayrıntı: $code\n\n'
                '${sha1.isEmpty ? '' : 'Uygulama imzası (SHA-1):\n${sha1.join('\n')}\n\n'}'
                'Google girişini tarayıcıda yapabilirsin.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tarayıcıyla devam et')),
            ],
          ),
        );
        if (useBrowser == true) {
          final viaBrowser =
              await AccountService.instance.signInWithGoogleBrowser();
          if (viaBrowser != null && mounted) {
            await _finishOnboarding();
            return;
          }
        }
      }
    } on DifferentAccountDataException {
      await _resolveAccountSwitch();
    } on AccountException catch (e) {
      _showError(e.message);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Telefonda başka bir hesaba ait veri var: cihazda aynı anda tek hesap kullanılır.
  Future<void> _resolveAccountSwitch() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu telefonda başka bir hesabın verisi var'),
        content: const Text(
            'FinScout bir telefonda aynı anda tek hesapla kullanılır. Bu hesabın verileri (ekstre, işlem, hedef, '
            'varlık) kullanım boyunca otomatik olarak hesabına şifreli şekilde yedeklenir; devam edersen bu '
            'telefondan kaldırılır ama kaybolmaz — bu hesapla tekrar giriş yaptığında otomatik olarak geri gelir. '
            'Şimdi seçtiğin hesaba geçilecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AccountService.instance.confirmAccountSwitch();
        if (mounted) await _finishOnboarding();
      } on AccountException catch (e) {
        _showError(e.message);
      }
    } else {
      await AccountService.instance.cancelAccountSwitch();
    }
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
      if (mounted) await _finishOnboarding();
    } on DifferentAccountDataException {
      await _resolveAccountSwitch();
      if (mounted) setState(() => _isLoading = false);
    } on AccountException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kayıt Ol / Giriş Yap metinleri AppStrings.get(...) ile okunur; dil değişince (Ayarlar > Dil)
    // bu ekran açıkken de anında güncellensin diye locale dinlenir.
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.currentLocale,
      builder: (context, _, __) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          // Tablet/yatay ekranda form ortada, en fazla 560 dp (telefonda değişiklik yok)
          child: AdaptiveBody(
            maxWidth: 560,
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
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.24),
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
                      Text(
                        'FinScout',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimaryOf(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.get('tagline'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Frontend Joe Pure CSS Sliding Overlay Dual-Card
                SlidingOverlayCard(
                  height: 142,
                  borderRadius: 22,
                  isSecondary: _isSignInMode,
                  onToggle: (val) {
                    setState(() {
                      _isSignInMode = val;
                    });
                  },
                  // Mod 1: Kayıt Ol (Sign Up) -> Kapak Sağda
                  primaryHeroTitle:
                      AppStrings.get('onboarding_signin_prompt_title'),
                  primaryHeroSubtitle:
                      AppStrings.get('onboarding_signin_prompt_subtitle'),
                  primaryButtonText:
                      AppStrings.get('onboarding_toggle_signin_btn'),
                  primaryGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF047857), Color(0xFF0F172A)],
                  ),
                  primaryForm: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded,
                              color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              AppStrings.get('onboarding_form_signup_chip'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.get('onboarding_form_signup_chip_subtitle'),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.3),
                      ),
                    ],
                  ),

                  // Mod 2: Giriş Yap (Sign In) -> Kapak Solda
                  secondaryHeroTitle:
                      AppStrings.get('onboarding_signup_prompt_title'),
                  secondaryHeroSubtitle:
                      AppStrings.get('onboarding_signup_prompt_subtitle'),
                  secondaryButtonText:
                      AppStrings.get('onboarding_toggle_signup_btn'),
                  secondaryGradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2563EB), Color(0xFF0F172A)],
                  ),
                  secondaryForm: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_open_rounded,
                              color: Color(0xFF2563EB), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              AppStrings.get('onboarding_form_signin_chip'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.get('onboarding_form_signin_chip_subtitle'),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.3),
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
      ),
    );
  }

  // ==========================================
  // 1. KAYIT OL FORMU (Sign Up)
  // ==========================================
  Widget _buildSignUpForm() {
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.cardOf(context),
      borderRadius: 22,
      border: Border.all(color: AppColors.borderOf(context)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.get('onboarding_signup_form_title'),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryOf(context)),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.get('onboarding_signup_form_subtitle'),
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondaryOf(context)),
          ),
          const SizedBox(height: 16),
          _googleButton(),
          _orDivider(),

          // Ad Soyad
          Text(
            AppStrings.get('onboarding_name_field_label'),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: AppColors.textPrimaryOf(context)),
            decoration: InputDecoration(
              hintText: AppStrings.get('onboarding_name_hint'),
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: Icon(Icons.person_outline_rounded,
                  color: AppColors.textSecondaryOf(context), size: 20),
              filled: true,
              fillColor: AppColors.subtleFillOf(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF0052FF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            AppStrings.get('onboarding_email_field_label'),
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context)),
          ),
          const SizedBox(height: 8),
          _inputField(
            controller: _emailController,
            hint: AppStrings.get('onboarding_email_hint'),
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          // Başla Butonu
          ConstrainedBox(
            constraints:
                const BoxConstraints(minWidth: double.infinity, minHeight: 52),
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
                  : Text(
                      AppStrings.get('onboarding_send_code_btn'),
                      style: const TextStyle(
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
    return FinanceCard(
      padding: const EdgeInsets.all(22),
      color: AppColors.cardOf(context),
      borderRadius: 22,
      border: Border.all(color: AppColors.borderOf(context)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
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
          Text(
            AppStrings.get('onboarding_signin_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryOf(context)),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.get('onboarding_signin_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
                height: 1.4),
          ),
          const SizedBox(height: 16),
          _googleButton(),
          _orDivider(),
          _inputField(
            controller: _signInEmailController,
            hint: AppStrings.get('onboarding_email_hint'),
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints:
                const BoxConstraints(minWidth: double.infinity, minHeight: 48),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _startEmailSignIn,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(AppStrings.get('onboarding_send_signin_code_btn'),
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800)),
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
            child: Text(AppStrings.get('onboarding_no_account_btn'),
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _googleButton() {
    // En az 50 dp; büyük yazıda düğme uzar (sabit yükseklik yazıyı taşırıyordu)
    return ConstrainedBox(
      constraints:
          const BoxConstraints(minWidth: double.infinity, minHeight: 50),
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryOf(context),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('G',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4))),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(AppStrings.get('onboarding_google_btn'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _orDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.borderOf(context))),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(AppStrings.get('onboarding_or_email_divider'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondaryOf(context))),
            ),
          ),
          Expanded(child: Divider(color: AppColors.borderOf(context))),
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
      style: TextStyle(color: AppColors.textPrimaryOf(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        prefixIcon: Icon(icon, color: AppColors.textSecondaryOf(context), size: 20),
        filled: true,
        fillColor: AppColors.subtleFillOf(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.borderOf(context)),
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
    return FinanceCard(
      padding: const EdgeInsets.all(20),
      color: AppColors.cardOf(context),
      borderRadius: 22,
      border: Border.all(color: AppColors.borderOf(context)),
      boxShadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.get('onboarding_code_step_title'),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryOf(context)),
          ),
          const SizedBox(height: 4),
          Text(
            '$_codeSentTo ${AppStrings.get('onboarding_code_instructions')}',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
                height: 1.4),
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
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: AppColors.textPrimaryOf(context)),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••••',
              filled: true,
              fillColor: AppColors.subtleFillOf(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
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
                  : Text(AppStrings.get('onboarding_verify_btn'),
                      style: const TextStyle(
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
                child: Text(AppStrings.get('onboarding_change_email_btn')),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _sendCode(_codeSentTo!,
                        signup: _codeIsForSignup,
                        fullName: _codeIsForSignup
                            ? _nameController.text.trim()
                            : null),
                child: Text(AppStrings.get('onboarding_resend_code_btn')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
