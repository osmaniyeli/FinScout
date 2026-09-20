// lib/features/onboarding/presentation/onboarding_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/database/app_database.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({Key? key, required this.onCompleted}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  String _selectedBank = 'Garanti BBVA';
  String _selectedCurrency = 'TRY';
  bool _isLoading = false;

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
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.expenseRed,
          content: Text('Lütfen devam etmek için adınızı veya takma adınızı girin.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final budgetStr = _budgetController.text.replaceAll('.', '').replaceAll(',', '').trim();
      final budgetCents = (int.tryParse(budgetStr) ?? 0) * 100;

      // 1. Kullanıcı profilini yerel olarak kaydet
      final profile = UserProfile(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        currency: _selectedCurrency,
        monthlyBudgetCents: budgetCents,
        joinedAt: DateTime.now(),
      );
      await UserProfileService.instance.saveProfile(profile);

      // 2. Birincil hesabı veritabanında oluştur
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Logo ve Başlık
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '₺',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppStrings.get('onboarding_welcome_title'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  AppStrings.get('onboarding_welcome_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Ad Soyad
              const Text(
                'Adınız veya Kullanıcı Adınız *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Örn: Ahmet Yılmaz',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              ),
              const SizedBox(height: 20),

              // Başlıca Banka / Hesap
              const Text(
                'Birincil Banka veya Hesap',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                    items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedBank = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Aylık Bütçe Hedefi (Opsiyonel)
              const Text(
                'Aylık Harcama Bütçesi Hedefi (TL)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Örn: 25000 (Opsiyonel)',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: const Icon(Icons.savings_outlined, color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              ),
              const SizedBox(height: 32),

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
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Başla Butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeOnboarding,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          AppStrings.get('start_app_btn'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
