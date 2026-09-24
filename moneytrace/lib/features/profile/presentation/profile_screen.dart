// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../../settings/presentation/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLoggedOut;

  const ProfileScreen({Key? key, this.onLoggedOut}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileService _profileService = UserProfileService.instance;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _budgetController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final p = _profileService.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    final budgetTl = ((p?.monthlyBudgetCents ?? 0) / 100).toInt();
    _budgetController = TextEditingController(text: budgetTl > 0 ? budgetTl.toString() : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    final current = _profileService.profile;
    final budgetStr = _budgetController.text.replaceAll('.', '').replaceAll(',', '').trim();
    final budgetCents = (int.tryParse(budgetStr) ?? 0) * 100;

    final updated = UserProfile(
      id: current?.id ?? 'default_user',
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : (current?.name ?? 'Kullanıcı'),
      email: _emailController.text.trim(),
      currency: current?.currency ?? 'TRY',
      monthlyBudgetCents: budgetCents,
      joinedAt: current?.joinedAt ?? DateTime.now(),
    );

    await _profileService.saveProfile(updated);
    setState(() => _isEditing = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.incomeGreen,
          content: Text('Profil bilgileriniz başarıyla güncellendi.'),
        ),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStrings.get('logout_btn')),
        content: const Text('Hesabından çıkış yapılsın mı? Ekstre ve işlemlerin bu telefonda kalır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _profileService.logOut();
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                widget.onLoggedOut?.call();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expenseRed),
            child: Text(AppStrings.get('logout_btn'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileService.profile;
    final initials = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    final joinedStr = profile != null
        ? '${profile.joinedAt.day}.${profile.joinedAt.month}.${profile.joinedAt.year}'
        : '-';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppStrings.get('profile_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined),
            onPressed: () {
              if (_isEditing) {
                _saveProfileChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
            tooltip: _isEditing ? AppStrings.get('save') : AppStrings.get('profile_edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Profil Avatar & İsim Kartı
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.name ?? AppStrings.get('guest_user'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  if (profile?.email.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile!.email,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Kişisel Bilgiler Form / Liste Kartı
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KİŞİSEL DETAYLAR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 16),

                  // Ad Soyad
                  _buildFieldRow(
                    label: AppStrings.get('profile_name'),
                    icon: Icons.person_outline_rounded,
                    child: _isEditing
                        ? TextField(controller: _nameController, decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()))
                        : Text(profile?.name ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  const Divider(height: 24),

                  // E-posta / İletişim
                  _buildFieldRow(
                    label: AppStrings.get('profile_email'),
                    icon: Icons.email_outlined,
                    child: _isEditing
                        ? TextField(controller: _emailController, decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()))
                        : Text(profile?.email.isNotEmpty == true ? profile!.email : 'Belirtilmedi', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                  const Divider(height: 24),

                  // Para Birimi
                  _buildFieldRow(
                    label: AppStrings.get('profile_currency'),
                    icon: Icons.currency_lira_rounded,
                    child: Text('${profile?.currency ?? "TRY"} (Türk Lirası)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  const Divider(height: 24),

                  // Aylık Bütçe Hedefi
                  _buildFieldRow(
                    label: AppStrings.get('profile_budget_target'),
                    icon: Icons.savings_outlined,
                    child: _isEditing
                        ? TextField(controller: _budgetController, keyboardType: TextInputType.number, decoration: const InputDecoration(isDense: true, suffixText: 'TL', border: UnderlineInputBorder()))
                        : Text(
                            (profile?.monthlyBudgetCents ?? 0) > 0
                                ? CurrencyNormalizer.formatCents(profile!.monthlyBudgetCents)
                                : 'Belirlenmedi',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0052FF)),
                          ),
                  ),
                  const Divider(height: 24),

                  // Üyelik / Kayıt Tarihi
                  _buildFieldRow(
                    label: AppStrings.get('profile_joined_date'),
                    icon: Icons.calendar_today_outlined,
                    child: Text(joinedStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. EN ALT ALAN: Uygulama Ayarları, Çıkış Yap
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.settings_outlined, color: AppColors.textPrimary, size: 20),
                    ),
                    title: Text(AppStrings.get('app_settings_btn'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Güvenlik, yedekleme, abonelik ve gizlilik',style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                      );
                    },
                  ),

                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout_rounded, color: AppColors.expenseRed, size: 20),
                    ),
                    title: Text(AppStrings.get('logout_btn'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.expenseRed)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.expenseRed),
                    onTap: _showLogoutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow({required String label, required IconData icon, required Widget child}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
        Expanded(child: child),
      ],
    );
  }
}
