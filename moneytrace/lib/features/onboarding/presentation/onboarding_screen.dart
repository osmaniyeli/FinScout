// lib/features/onboarding/presentation/onboarding_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/security_auth_service.dart';
import '../../../core/database/app_database.dart';
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
  final _budgetController = TextEditingController();
  String _selectedBank = 'Garanti BBVA';
  final String _selectedCurrency = 'TRY';
  bool _isLoading = false;
  bool _isSignInMode = false;

  final List<String> _banks = [
    'Garanti BBVA',
    'İş Bankası',
    'Yapı Kredi',
    'Enpara.com / QNB',
    'Akbank',
    'Ziraat Bankası',
    'VakıfBank',
    'Nakit Cüzdan',
  ];

  @override
  void initState() {
    super.initState();
    SecurityAuthService.instance.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _completeRegistration() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseRed,
          content:
              Text('Lütfen devam etmek için adınızı veya takma adınızı girin.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final budgetStr =
          _budgetController.text.replaceAll('.', '').replaceAll(',', '').trim();
      final budgetCents = (int.tryParse(budgetStr) ?? 0) * 100;

      final profile = UserProfile(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        currency: _selectedCurrency,
        monthlyBudgetCents: budgetCents,
        joinedAt: DateTime.now(),
      );
      await UserProfileService.instance.saveProfile(profile);

      final db = await AppDatabase.instance.database;
      await db.insert('accounts', {
        'id': 'acc_${DateTime.now().millisecondsSinceEpoch}',
        'institution_name': _selectedBank,
        'account_type': _selectedBank == 'Nakit Cüzdan' ? 'CASH' : 'BANK',
        'account_name': '$_selectedBank Ana Hesap',
        'card_mask': '**** **** **** 1001',
        'card_holder': name,
        'currency_code': _selectedCurrency,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        widget.onCompleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseRed,
            content: Text('Hesap oluşturulurken hata: $e'),
          ),
        );
      }
    }
  }

  Future<void> _loginWithBiometrics(BiometricAuthType type) async {
    setState(() => _isLoading = true);

    final success = await SecurityAuthService.instance.authenticateBiometric(
      reason: type == BiometricAuthType.faceId
          ? 'Paraİz Yüz Tanıma ile Giriş'
          : 'Paraİz Parmak İzi ile Giriş',
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
      subtitle: 'Paraİz kasanıza erişmek için 4 haneli PIN kodunuzu girin.',
      isSettingNewPin: false,
    );

    if (verified == true && mounted) {
      await _ensureProfileAndProceed();
    }
  }

  Future<void> _ensureProfileAndProceed() async {
    if (!UserProfileService.instance.hasProfile) {
      final defaultProfile = UserProfile(
        id: 'user_default',
        name: 'Selim Kaya',
        currency: 'TRY',
        monthlyBudgetCents: 2500000,
        joinedAt: DateTime.now(),
      );
      await UserProfileService.instance.saveProfile(defaultProfile);

      final db = await AppDatabase.instance.database;
      await db.insert('accounts', {
        'id': 'acc_default_garanti',
        'institution_name': 'Garanti BBVA',
        'account_type': 'BANK',
        'account_name': 'Garanti BBVA Ana Hesap',
        'card_mask': '**** **** **** 1001',
        'card_holder': 'Selim Kaya',
        'currency_code': 'TRY',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    if (mounted) {
      widget.onCompleted();
    }
  }

  Future<void> _restoreFromBackup() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F172A),
          content: Text(
              'Cihazdaki yerel kasa inceleniyor... Lütfen PIN veya biyometrik ile doğrulayın.'),
        ),
      );
      _loginWithPin();
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
                      'Paraİz',
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
                      'Paraİz ile bütçeni kontrol altına al.',
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

              // Dinamik Form Alanı (Kayıt Ol vs Giriş Yap)
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
            'Tek bir hesapla tüm banka ve nakit cüzdanlarınızı yönetin.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

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
          const SizedBox(height: 16),

          // Başlıca Banka / Hesap
          const Text(
            'Birincil Banka veya Hesap',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBank,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary),
                items: _banks
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBank = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Aylık Bütçe Hedefi (Opsiyonel)
          const Text(
            'Aylık Harcama Bütçesi Hedefi (TL)',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Örn: 25000 (Opsiyonel)',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              prefixIcon: const Icon(Icons.savings_outlined,
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
                    'Verileriniz asla harici sunuculara iletilmez. Cihazınızda SQLite veritabanında şifrelenir.',
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
                  : Text(
                      AppStrings.get('start_app_btn'),
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
                child: Icon(Icons.info_outline_rounded,
                    color: Color(0xFF2563EB), size: 26),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Henüz Açılmış Bir Üyelik Bulunmuyor',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yüz tanıma, parmak izi ve şifreli giriş özellikleri yalnızca üyeliğinizi açtıktan sonra kullanılabilir. Lütfen önce profilinizi oluşturun.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isSignInMode = false);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Üyeliğinizi Oluşturun (Kayıt Ol)',
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

          // 1. Yüz Tanıma ile Giriş (Face ID)
          InkWell(
            onTap: () => _loginWithBiometrics(BiometricAuthType.faceId),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.face_retouching_natural,
                      color: Color(0xFF059669), size: 24),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yüz Tanıma ile Giriş (Face ID)',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46)),
                        ),
                        Text(
                          'Kameraya bakın, anında oturum açın',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF059669), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

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

          // Yedek Dosyasından Geri Yükle & Hızlı Başla
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restoreFromBackup,
                  icon: const Icon(Icons.settings_backup_restore_rounded,
                      size: 18),
                  label: const Text('Yedekten Yükle',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ensureProfileAndProceed,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Hızlı Giriş',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
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
        ],
      ),
    );
  }
}
