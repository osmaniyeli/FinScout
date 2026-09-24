import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/laser_shimmer_card.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/config/app_links.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';
import '../../family/presentation/family_screen.dart';
import '../../../core/services/security_auth_service.dart';
import '../../../core/widgets/fintech/security_auth_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService.instance;
  final TransactionRepository _repository = TransactionRepository();
  final DataExportService _exportService = DataExportService.instance;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
  }

  void _showSubscriptionPlans() {
    SubscriptionPlansSheet.show(context);
  }

  Future<void> _setNewPin() async {
    final res = await SecurityAuthSheet.show(
      context,
      title: 'Yeni Güvenlik PIN Kodu Belirleyin',
      subtitle: '4 haneli güvenli PIN kodunuzu girin.',
      isSettingNewPin: true,
      allowBiometrics: false,
    );
    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content:
              Text('Güvenlik PIN kodu başarıyla oluşturuldu ve aktif edildi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _changeExistingPin() async {
    String? currentPin;
    final verified = await SecurityAuthSheet.show(
      context,
      title: 'Mevcut PIN Kodunuzu Girin',
      subtitle:
          'Şifrenizi değiştirmek için lütfen mevcut PIN kodunuzu doğrulayın.',
      allowBiometrics: false,
      onPinEntered: (pin) {
        currentPin = pin;
      },
    );

    if (verified != true || currentPin == null || !mounted) return;

    final newPinSet = await SecurityAuthSheet.show(
      context,
      title: 'Yeni PIN Kodunu Belirleyin',
      subtitle: 'Kullanmak istediğiniz yeni 4 haneli PIN kodunu girin.',
      isSettingNewPin: true,
      allowBiometrics: false,
    );

    if (newPinSet == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF059669),
          content: Text('Güvenlik PIN kodunuz başarıyla güncellendi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removePinWithVerification() async {
    String? enteredPin;
    final verified = await SecurityAuthSheet.show(
      context,
      title: 'Şifreyi Kaldırmak İçin Mevcut PIN Girin',
      subtitle:
          'Güvenliğiniz için lütfen mevcut 4 haneli PIN kodunuzu girerek şifreyi kaldırın.',
      allowBiometrics: false,
      onPinEntered: (pin) {
        enteredPin = pin;
      },
    );

    if (verified == true && enteredPin != null) {
      final success = await SecurityAuthService.instance.removePin(enteredPin!);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF0F172A),
              content: Text('Güvenlik PIN kodu başarıyla kaldırıldı.'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.expenseRed,
              content: Text('Hatalı PIN kodu! Şifre kaldırılamadı.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ayarlar & Tercihler',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Plan Kartı (Google Play Billing Entegrasyonu)
            LaserShimmerCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(18),
              backgroundColor: const Color(0xFF0F172A),
              shimmerColor: _subscriptionService.isPremium
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF38BDF8),
              borderColor: const Color(0xFF334155),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AKTİF PLANINIZ',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5),
                      ),
                      PulseMetricBadge(
                        label: _subscriptionService.isPremium
                            ? 'GÜVENLİ'
                            : 'TEMEL',
                        value: _subscriptionService.isPremium
                            ? 'PREMIUM AKTİF'
                            : 'ÜCRETSİZ PLAN',
                        pulseColor: _subscriptionService.isPremium
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF38BDF8),
                        isPositive: _subscriptionService.isPremium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subscriptionService.isPremium
                        ? (_subscriptionService.isFamilyPlan
                            ? (_subscriptionService.isFamilyMemberEntitlement
                                ? 'Aile Paketi (üye)'
                                : 'Aile Paketi (sahip)')
                            : (_subscriptionService.isAnnualPlan
                                ? 'Bireysel Yıllık Premium'
                                : 'Bireysel Aylık Premium'))
                        : 'Ücretsiz Başlangıç Paketi',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Google Play Store Güvencesiyle',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _showSubscriptionPlans,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_subscriptionService.isPremium
                        ? 'Planı Değiştir veya Yönet'
                        : 'Premium Avantajlarını Keşfet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Abonelik ve yasal bağlantılar (Play politikaları uygulama içinde istiyor)
            const Text(
              'ABONELİK VE GİZLİLİK',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.family_restroom_rounded, color: AppColors.textSecondary),
              title: const Text('Aile',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Premium hakkını en fazla 4 kişiyle paylaş; veriler paylaşılmaz',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () async {
                await Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const FamilyScreen()));
                if (mounted) setState(() {});
              },
            ),
            _buildLinkTile(Icons.credit_card_rounded, 'Aboneliği yönet / iptal et',
                'Google Play abonelik sayfası açılır', AppLinks.manageSubscriptions()),
            _buildLinkTile(Icons.privacy_tip_outlined, 'Gizlilik politikası',
                'Hangi verinin nerede tutulduğu', AppLinks.privacyPolicy),
            _buildLinkTile(Icons.person_remove_outlined, 'Hesap ve veri silme',
                'Uygulamadan ya da e-postayla silme yolları', AppLinks.dataDeletion),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined, color: AppColors.textSecondary),
              title: const Text('Açık kaynak lisansları',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              subtitle: const Text('Uygulamada kullanılan kütüphaneler',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () => showLicensePage(context: context, applicationName: 'FinScout'),
            ),
            const SizedBox(height: 24),

            // 2. GÜVENLİK & BİYOMETRİK KORUMA (Face ID, Fingerprint, PIN)
            const Text(
              'GİZLİLİK & BİYOMETRİK GÜVENLİK',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            // Kriptolu Depolama Rozeti
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.verified_user_rounded,
                        color: AppColors.incomeGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Veriler bu telefonda',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ekstreler telefonunda okunur; ekstre ve işlemlerin sunucuya gönderilmez. Sunucuda yalnız hesap bilgin (ad, e-posta) tutulur.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Parmak İzi (Touch ID / Fingerprint) Switch Tile
            ValueListenableBuilder<bool>(
              valueListenable:
                  SecurityAuthService.instance.isFingerprintEnabledNotifier,
              builder: (context, isFpEnabled, _) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.fingerprint_rounded,
                            color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Parmak izi ile giriş',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Telefonun parmak izi sensörüne dokunarak cüzdanınıza erişin.',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isFpEnabled,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: (val) async {
                          final error = val
                              ? await SecurityAuthService.instance
                                  .enableBiometric(
                                      BiometricAuthType.fingerprint)
                              : null;
                          if (!val)
                            await SecurityAuthService.instance
                                .setFingerprintEnabled(false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: error != null
                                    ? AppColors.expenseRed
                                    : (val
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF0F172A)),
                                content: Text(error ??
                                    (val
                                        ? 'Parmak izi ile giriş açıldı.'
                                        : 'Parmak İzi devre dışı bırakıldı.')),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // 3. 4 Haneli Güvenlik Şifresi / PIN Kodu Tile
            ValueListenableBuilder<bool>(
              valueListenable: SecurityAuthService.instance.hasPinSetNotifier,
              builder: (context, hasPin, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.pin_rounded,
                                color: Color(0xFF0F172A), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasPin
                                      ? 'Güvenlik Şifresi / PIN Kodu (Aktif)'
                                      : '4 Haneli Şifre / PIN Belirle',
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasPin
                                      ? 'Cihaz kasası SHA-256 tuzlu PIN ile korunuyor.'
                                      : 'Uygulama açılışını 4 haneli sayısal şifre ile koruyun.',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (!hasPin)
                            ElevatedButton(
                              onPressed: _setNewPin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                elevation: 0,
                              ),
                              child: const Text('Şifre Belirle',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      if (hasPin) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _changeExistingPin,
                                icon: const Icon(Icons.edit_rounded, size: 14),
                                label: const Text('Şifreyi Değiştir',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(
                                      color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _removePinWithVerification,
                                icon: const Icon(Icons.lock_open_rounded,
                                    size: 14, color: AppColors.expenseRed),
                                label: const Text('Şifreyi Kaldır',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.expenseRed)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.expenseRed,
                                  side: const BorderSide(
                                      color: Color(0xFFFECDD3)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 4. VERİ YÖNETİMİ & YEDEKLEME (ZERO-KNOWLEDGE)
            const Text(
              'VERİ YÖNETİMİ VE YEDEKLEME',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            // 1. CSV / Excel Raporu (Morflayan Buton)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.table_chart_rounded,
                            color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Harcama raporu (Excel / CSV)',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text(
                                'Tüm işlemler; taksit ve vergi satırları işlem başına tek satırda.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _plainActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'CSV raporunu oluştur ve paylaş',
                    onPressed: _isExporting ? null : _exportToCsv,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Tam Sistem Yedeği (Radar Doğrulama Butonu)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.security_rounded,
                            color: AppColors.actionPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Yedek al',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text(
                                'Hesaplar, ekstreler, işlemler, taksitler ve vergi satırları. İstersen parolayla şifrelenir.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _plainActionButton(
                    icon: Icons.save_alt_rounded,
                    label: 'Yedek dosyası oluştur',
                    onPressed: _exportToJsonBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Yedekten Geri Yükle (İnteraktif Yükleme Butonu)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.settings_backup_restore_rounded,
                            color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Yedekten Geri Yükle',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text(
                                'Telefondaki mevcut kayıtlar silinir, yerine yedektekiler gelir.',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _plainActionButton(
                    icon: Icons.settings_backup_restore_rounded,
                    label: 'Yedek dosyası seç ve geri yükle',
                    onPressed: _restoreFromJsonBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. TEHLİKELİ BÖLGE: TÜM VERİLERİMİ SIFIRLA VE SİL
            const Text(
              'TEHLİKELİ BÖLGE / VERİLERİ SIFIRLA',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.expenseRed,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_forever_rounded,
                            color: AppColors.expenseRed, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tüm Verilerimi Sıfırla ve Sil',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.expenseRed),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hesaplar, ekstreler, harcamalar, hedefler ve profil cihazınızdan tamamen silinir.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9F1239),
                                  height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmAndResetAllData,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Tüm Verilerimi Sıfırla ve Hesabı Sil',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expenseRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 84),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkTile(IconData icon, String title, String subtitle, String url) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.textSecondary),
      onTap: () => AppLinks.open(url),
    );
  }

  Widget _plainActionButton(
      {required IconData icon, required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    try {
      final exportData = await _repository.getAllDataForExport();
      final txList = (exportData['transactions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final csvContent = _exportService.exportToCsv(txList);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/FinScout_Harcama_Raporu.csv');
      await file.writeAsString(csvContent);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'FinScout Harcama ve İşlem Raporu (Excel / CSV)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV paylaşılırken hata: $e')),
        );
      }
    }
  }

  Future<void> _exportToJsonBackup() async {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('Sistem Yedeği Al',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yedeğinizi AES-256 ile şifrelemek için bir koruma parolası belirleyin (Önerilen). Boş bırakırsanız düz metin JSON olarak kaydedilir.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Kasa Parolası (En az 6 karakter)',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('🔒 Güvenli Şifreli Yedek (.vault)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final pwd = passwordController.text.trim();
              if (pwd.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.expenseRed,
                    content: Text(
                        'Güvenli yedek için parola en az 6 karakter olmalıdır!'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              await _executeExportProcess(password: pwd);
            },
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _executeExportProcess(password: null);
            },
            child: const Text('Şifresiz JSON Al',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeExportProcess({String? password}) async {
    setState(() => _isExporting = true);
    try {
      final data = await _repository.getAllDataForExport();
      final accounts = (data['accounts'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final statements = (data['statements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final transactions = (data['transactions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final installments = (data['installments'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final taxes = (data['tax_deductions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final extras = {
        for (final t in TransactionRepositoryBackup.extraTables)
          t: (data[t] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      };

      final isEncrypted = password != null && password.isNotEmpty;
      final content = isEncrypted
          ? _exportService.createEncryptedVaultBackup(
              accounts: accounts,
              statements: statements,
              transactions: transactions,
              installments: installments,
              taxes: taxes,
              extras: extras,
              password: password,
            )
          : _exportService.createFullVaultBackupJson(
              accounts: accounts,
              statements: statements,
              transactions: transactions,
              installments: installments,
              taxes: taxes,
              extras: extras,
            );

      final tempDir = await getTemporaryDirectory();
      final fileName = isEncrypted
          ? 'FinScout_Sistem_Yedegi.vault'
          : 'FinScout_Sistem_Yedegi.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [
          XFile(file.path,
              mimeType:
                  isEncrypted ? 'application/octet-stream' : 'application/json')
        ],
        text: isEncrypted
            ? 'FinScout AES-256 Şifreli Kasa Yedeği (.vault)'
            : 'FinScout Sistem Yedeği (JSON)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedek üretilirken hata: $e')),
        );
      }
    }
  }

  void _confirmAndResetAllData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.expenseRed, size: 24),
            SizedBox(width: 8),
            Text('Tüm Verileri Sil?',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.expenseRed)),
          ],
        ),
        content: const Text(
          'Bu işlem FinScout hesabını (ad, e-posta ve sunucudaki tüm kayıtlar) ve telefonundaki tüm hesapları, ekstreleri, harcama kayıtlarını, hedefleri, varlıkları ve kurulu hatırlatmaları kalıcı olarak siler.\n\n'
          'Google Play aboneliğin varsa hesabı silmek onu iptal etmez; "Aboneliği yönet / iptal et" bağlantısından ayrıca iptal et.\n\n'
          'Bu işlem geri alınamaz. Devam etmek istiyor musun?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Önce sunucudaki hesap: başarısızsa cihaz verisi korunur, kullanıcı tekrar dener
              try {
                await AccountService.instance.deleteAccount();
              } on AccountException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: AppColors.expenseRed,
                      content: Text(e.message)));
                }
                return;
              }
              await _repository.clearAllUserData();
              await UserProfileService.instance.resetAllUserData();
              await SecurityAuthService.instance.resetAll();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.expenseRed,
                    content: Text(
                        'Tüm verileriniz ve hesabınız başarıyla sıfırlandı.'),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expenseRed,
                foregroundColor: Colors.white),
            child: const Text('Evet, Hepsini Sil',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Yedek dosyasını seçtirir (.vault / .json); vazgeçilirse metin yapıştırma yolu açık kalır.
  Future<void> _restoreFromJsonBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );

      var decodedText = '';
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name.toLowerCase();
        if (!fileName.endsWith('.json') && !fileName.endsWith('.vault')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.expenseRed,
                content: Text(
                    'Geçersiz dosya biçimi! Yalnızca .json veya .vault uzantılı dosyalar desteklenir.'),
              ),
            );
          }
          return;
        }

        if (file.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.expenseRed,
                content: Text('Dosya içeriği okunamadı.'),
              ),
            );
          }
          return;
        }

        decodedText = utf8.decode(file.bytes!);
      }

      if (!mounted) return;

      final controller = TextEditingController(text: decodedText);
      final passController = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isVault =
                  controller.text.trim().startsWith('PARAIZ-SEC-VAULT-V2:');

              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.settings_backup_restore_rounded,
                        color: AppColors.actionPrimary, size: 22),
                    SizedBox(width: 8),
                    Text('Yedekten Geri Yükle',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Yedek dosyasından okunan veri içeriği (gerekirse düzenleyin):',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: controller,
                        maxLines: 4,
                        onChanged: (_) => setDialogState(() {}),
                        style: const TextStyle(
                            fontSize: 11, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'PARAIZ-SEC-VAULT-V2:... veya JSON metni',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                      if (isVault) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_rounded,
                                  color: Color(0xFF059669), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bu yedek AES-256 ile şifrelenmiştir. Çözmek için belirlediğiniz parolayı giriniz.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF065F46),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Kasa Parolası',
                            prefixIcon: const Icon(Icons.key_rounded, size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('İptal')),
                  ElevatedButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;

                      try {
                        final pwd = passController.text.trim();
                        final parsed = _exportService.validateAndParseBackup(
                          text,
                          password: pwd.isNotEmpty ? pwd : null,
                        );
                        await _repository.restoreVaultBackup(parsed);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF10B981),
                              content: Text(
                                  'Yedek başarıyla geri yüklendi! Verileriniz güncellendi.'),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              backgroundColor: AppColors.expenseRed,
                              content: Text('Geri yükleme hatası: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.actionPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Geri Yükle'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expenseRed,
            content: Text('Dosya seçme hatası: $e'),
          ),
        );
      }
    }
  }
}
