import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/laser_shimmer_card.dart';
import '../../../core/config/app_links.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';
import '../../family/presentation/family_screen.dart';
import '../../../core/services/security_auth_service.dart';
import '../../../core/widgets/fintech/security_auth_sheet.dart';
import 'licenses_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
                  const Text(
                    'AKTİF PLANINIZ',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5),
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
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LicensesScreen())),
            ),
            const SizedBox(height: 24),

            // 2. GÜVENLİK (uygulama kilidi: yalnız PIN)
            const Text(
              'GÜVENLİK',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5),
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
                                      ? "PIN'in bu telefonda şifrelenmiş olarak saklanır."
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

            // 4. VERİ YÖNETİMİ (CSV raporu)
            const Text(
              'VERİ YÖNETİMİ',
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
}
