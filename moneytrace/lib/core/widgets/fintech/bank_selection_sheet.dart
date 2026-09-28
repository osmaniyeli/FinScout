// lib/core/widgets/fintech/bank_selection_sheet.dart

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/user_profile_service.dart';

/// Ücretsiz planda kullanıcının kilitleneceği tek bankayı seçtiği alt sayfa.
/// Onboarding sonrası (yeni hesap) ve Ayarlar > Banka'dan açılır (bkz. `.show`).
///
/// Aktif/seçilebilir bankalar: yalnız gerçek PDF korpusuyla doğrulanmış okuyucusu olanlar
/// (StatementOrchestrator._displayName ile birebir aynı görünen adlar — kilit karşılaştırması
/// bu string'lerle yapılır, bkz. statement_upload_sheet._prepareDocument).
class BankSelectionSheet extends StatelessWidget {
  final bool allowSkip;

  const BankSelectionSheet({super.key, this.allowSkip = false});

  static const List<String> _activeInstitutions = [
    'Yapı Kredi',
    'Garanti BBVA',
    'Enpara',
  ];

  /// Kullanıcı aktif bir bankayı seçip kilitlerse `true`, "Şimdi değil" ile vazgeçerse `false`,
  /// sheet dışına dokunup/sürükleyip kapatırsa `null` döner.
  static Future<bool?> show(BuildContext context, {bool allowSkip = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BankSelectionSheet(allowSkip: allowSkip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockedInstitution = UserProfileService.instance.profile?.lockedInstitution;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Bankanı Seç',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ücretsiz planda tek bankaya bağlı kalırsın; istediğinde Premium\'a geçip diğer bankaları da ekleyebilirsin.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            for (final name in _activeInstitutions) ...[
              _BankRow(
                name: name,
                isSelected: lockedInstitution == name,
                onTap: () async {
                  await UserProfileService.instance.setLockedInstitution(name);
                  if (context.mounted) Navigator.pop(context, true);
                },
              ),
              const SizedBox(height: 10),
            ],
            _BankRow(
              name: 'İş Bankası',
              isComingSoon: true,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'İş Bankası okuyucusu henüz hazır değil, yakında ekleniyor.'),
                  ),
                );
              },
            ),
            if (allowSkip) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Şimdi değil',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  final String name;
  final bool isSelected;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _BankRow({
    required this.name,
    required this.onTap,
    this.isSelected = false,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isComingSoon
              ? const Color(0xFFF8FAFC)
              : (isSelected ? const Color(0xFFEFF6FF) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isComingSoon
                ? const Color(0xFFE2E8F0)
                : (isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isComingSoon ? const Color(0xFFF1F5F9) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: isComingSoon ? AppColors.textMuted : AppColors.actionPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isComingSoon ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            if (isComingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Yakında',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
              )
            else if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0F172A), size: 22)
            else
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
