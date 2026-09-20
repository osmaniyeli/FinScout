import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/services/data_export_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/database/repositories/transaction_repository.dart';
import '../../../core/widgets/laser_shimmer_card.dart';
import '../../../core/widgets/pulse_metric_badge.dart';
import '../../../core/widgets/morphing_share_button.dart';
import '../../../core/widgets/radar_checkout_button.dart';
import '../../../core/widgets/interactive_file_upload_button.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/presentation/subscription_plans_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final RemoteConfigService _remoteConfig = RemoteConfigService.instance;
  final SubscriptionService _subscriptionService = SubscriptionService.instance;
  final TransactionRepository _repository = TransactionRepository();
  final DataExportService _exportService = DataExportService.instance;

  late String _selectedDataSource;
  late String _selectedLanguage;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedDataSource = _remoteConfig.marketDataSource;
    _selectedLanguage = AppStrings.currentLocale.value;
  }

  void _changeLanguage(String lang) {
    setState(() {
      _selectedLanguage = lang;
      _remoteConfig.setAppLanguage(lang);
    });

    UserProfileService.instance.updateLanguage(lang);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.incomeGreen,
        content: Text(
          lang == 'en'
              ? 'Language changed to English'
              : 'Uygulama dili Türkçe olarak güncellendi',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _changeDataSource(String source) {
    setState(() {
      _selectedDataSource = source;
      _remoteConfig.marketDataSource = source;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.incomeGreen,
        content: Text('Piyasa Veri Kaynağı Güncellendi: $source'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSubscriptionPlans() {
    SubscriptionPlansSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ayarlar & Tercihler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
              shimmerColor: _subscriptionService.isPremium ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
              borderColor: const Color(0xFF334155),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AKTİF PLANINIZ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                      ),
                      PulseMetricBadge(
                        label: _subscriptionService.isPremium ? 'GÜVENLİ' : 'TEMEL',
                        value: _subscriptionService.isPremium ? 'PREMIUM AKTİF' : 'ÜCRETSİZ PLAN',
                        pulseColor: _subscriptionService.isPremium ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                        isPositive: _subscriptionService.isPremium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subscriptionService.isPremium
                        ? (_subscriptionService.isFamilyPlan ? 'Aile Boyu Üyelik (4 Kişi)' : 'Bireysel Premium')
                        : 'Ücretsiz Başlangıç Paketi',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_subscriptionService.isPremium ? 'Planı Değiştir veya Yönet' : 'Premium Avantajlarını Keşfet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 1.5 DİL & İLETİŞİM TERCİHİ (Bilingual TR/EN)
            const Text(
              'DİL & İLETİŞİM TERCİHİ / LANGUAGE PREFERENCE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            _buildLanguageOptionTile(
              langKey: 'tr',
              title: 'Türkçe 🇹🇷',
              subtitle: 'Uygulama arayüzü, e-posta bültenleri ve finansal raporlar Türkçe hazırlanır.',
              badge: 'Varsayılan',
              badgeColor: const Color(0xFFDCFCE7),
              badgeTextColor: const Color(0xFF166534),
            ),
            const SizedBox(height: 8),

            _buildLanguageOptionTile(
              langKey: 'en',
              title: 'English 🇬🇧',
              subtitle: 'App interface, email newsletters, and financial exports delivered in English.',
              badge: 'Global',
              badgeColor: const Color(0xFFEFF6FF),
              badgeTextColor: AppColors.actionPrimary,
            ),
            const SizedBox(height: 24),

            // 2. VERİ KAYNAĞI SEÇİCİ
            const Text(
              'PİYASA VERİ KAYNAĞI SEÇİMİ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            _buildSourceOptionTile(
              sourceKey: 'TCMB',
              title: 'TCMB (Türkiye Cumhuriyet Merkez Bankası)',
              subtitle: 'Resmi kurlar, resmi gösterge fiyatları ve merkez bankası XML verisi.',
              badge: 'Resmi',
              badgeColor: const Color(0xFFDCFCE7),
              badgeTextColor: const Color(0xFF166534),
            ),
            const SizedBox(height: 8),

            _buildSourceOptionTile(
              sourceKey: 'KAPALICARSI',
              title: 'Kapalıçarşı & Serbest Piyasa',
              subtitle: 'Fiziki altın alış-satış makasları ve anlık döviz bürosu fiyatları.',
              badge: 'Önerilen',
              badgeColor: const Color(0xFFEFF6FF),
              badgeTextColor: AppColors.actionPrimary,
            ),
            const SizedBox(height: 24),

            // 3. GÜVENLİK & SIFIR SUNUCU PRENSİBİ
            const Text(
              'GİZLİLİK & GÜVENLİK',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

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
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.incomeGreen, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cihaz İçi Kriptolu Depolama',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ekstre ve finansal kayıtlarınız asla dış sunucuya gönderilmez. %100 telefonunuzda kalır.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. VERİ YÖNETİMİ & YEDEKLEME (ZERO-KNOWLEDGE)
            const Text(
              'VERİ YÖNETİMİ & YEDEKLEME (ZERO-KNOWLEDGE)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
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
                        child: const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Harcama Raporunu İndir (Excel / CSV)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('Türkçe karakter uyumlu (UTF-8 BOM), tüm harcama, taksit ve vergiler.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Video 2: Morflayan CSV İndirme & Paylaşma Butonu
                  MorphingShareButton(
                    fileName: 'ParaIz_Harcama_Raporu.csv',
                    label: 'Excel / CSV Raporunu İndir & Paylaş',
                    accentColor: const Color(0xFF10B981),
                    onDownloadComplete: _exportToCsv,
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
                        child: const Icon(Icons.security_rounded, color: AppColors.actionPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Tam Sistem Yedeği Al (JSON)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('Hesaplar, ekstreler, taksitler ve ayarları içeren taşınabilir arşiv.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Video 4: Radar Dalgalı Doğrulama ve Güvenli Kriptolu Yedekleme
                  RadarCheckoutButton(
                    label: 'Tam Yedeği Doğrula & Şifrele',
                    idleAmountText: 'JSON Arşiv',
                    verifyingAmountText: 'Kriptolanıyor...',
                    onPressed: _exportToJsonBackup,
                    onVerificationComplete: () {},
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
                        child: const Icon(Icons.settings_backup_restore_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Yedekten Geri Yükle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                            SizedBox(height: 2),
                            Text('Daha önce aldığınız bir Paraİz yedek dosyasını geri yükleyin.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Video 3: İnteraktif İlerleyen Dosya Yükleme Butonu
                  InteractiveFileUploadButton(
                    label: 'Yedek Dosyası Seç & Geri Yükle',
                    acceptedExtensions: const ['.json', '.enc'],
                    onFileSelected: (f) {
                      _restoreFromJsonBackup();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. UZAKTAN MODÜL DURUMU BİLGİSİ
            const Text(
              'SİSTEM SAĞLIĞI & MODÜLLER',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),



            _buildModuleStatusRow('Deterministik PDF Motoru', _remoteConfig.isModuleActive('statement_upload')),
            _buildModuleStatusRow('Nakit Akışı & Projeksiyon', _remoteConfig.isModuleActive('cashflow_projection')),
            _buildModuleStatusRow('Piyasa & Altın Veri Akışı', _remoteConfig.isModuleActive('market_rates')),
            _buildModuleStatusRow('Hedefler Modülü', _remoteConfig.isModuleActive('goals_module')),
            _buildModuleStatusRow('Aile Bütçesi Senkronizasyonu', _remoteConfig.isModuleActive('family_budget')),
            _buildModuleStatusRow('Piyasa Haberleri & Gündem', _remoteConfig.isModuleActive('market_news')),

            const SizedBox(height: 28),

            // 6. TEHLİKELİ BÖLGE: TÜM VERİLERİMİ SIFIRLA VE SİL
            const Text(
              'TEHLİKELİ BÖLGE / VERİLERİ SIFIRLA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.expenseRed, letterSpacing: 0.5),
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
                        child: const Icon(Icons.delete_forever_rounded, color: AppColors.expenseRed, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tüm Verilerimi Sıfırla ve Sil',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.expenseRed),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hesaplar, ekstreler, harcamalar, hedefler ve profil cihazınızdan tamamen silinir.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF9F1239), height: 1.3),
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
                      label: const Text('Tüm Verilerimi Sıfırla ve Hesabı Sil', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.expenseRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildLanguageOptionTile({
    required String langKey,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    final isSelected = _selectedLanguage == langKey;

    return InkWell(
      onTap: () => _changeLanguage(langKey),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.incomeGreen : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: langKey,
              groupValue: _selectedLanguage,
              activeColor: AppColors.incomeGreen,
              onChanged: (val) {
                if (val != null) _changeLanguage(val);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeTextColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOptionTile({
    required String sourceKey,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    final isSelected = _selectedDataSource == sourceKey;

    return InkWell(
      onTap: () => _changeDataSource(sourceKey),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.actionPrimary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: sourceKey,
              groupValue: _selectedDataSource,
              activeColor: AppColors.actionPrimary,
              onChanged: (val) {
                if (val != null) _changeDataSource(val);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeTextColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleStatusRow(String name, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          PulseMetricBadge(
            label: isActive ? 'CANLI' : 'BAKIM',
            value: isActive ? 'AKTİF' : 'KAPALI',
            pulseColor: isActive ? AppColors.incomeGreen : AppColors.expenseRed,
            isPositive: isActive,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isExporting ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.actionPrimary,
              elevation: 0,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCsv() async {
    setState(() => _isExporting = true);
    try {
      final exportData = await _repository.getAllDataForExport();
      final txList = (exportData['transactions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      final csvContent = _exportService.exportToCsv(txList);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ParaIz_Harcama_Raporu.csv');
      await file.writeAsString(csvContent);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'Paraİz Harcama ve İşlem Raporu (Excel / CSV)',
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

  void _showCsvResultModal(String csvContent, int rowCount, String filePath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Excel CSV Raporu Hazır', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          Text('$rowCount İşlem Satırı • UTF-8 BOM', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 140,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvContent,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF334155)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Share.shareXFiles(
                      [XFile(filePath, mimeType: 'text/csv')],
                      text: 'Paraİz Harcama ve İşlem Raporu (Excel / CSV)',
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Excel / Dosyayı Paylaş', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportToJsonBackup() async {
    setState(() => _isExporting = true);
    try {
      final data = await _repository.getAllDataForExport();
      final backupJson = _exportService.createFullVaultBackupJson(
        accounts: (data['accounts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        statements: (data['statements'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        transactions: (data['transactions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        installments: (data['installments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        taxes: (data['tax_deductions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/ParaIz_Sistem_Yedegi.json');
      await file.writeAsString(backupJson);

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: 'Paraİz Güvenli Kriptolu Sistem Yedeği (JSON)',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedek paylaşılırken hata: $e')),
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
            Icon(Icons.warning_amber_rounded, color: AppColors.expenseRed, size: 24),
            SizedBox(width: 8),
            Text('Tüm Verileri Sil?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.expenseRed)),
          ],
        ),
        content: const Text(
          'Bu işlem telefonunuzdaki tüm hesapları, yüklenmiş PDF ekstrelerini, harcama kayıtlarını, hedefleri ve kişisel bilgilerinizi kalıcı olarak sıfırlayacaktır.\n\nBu işlem geri alınamaz. Devam etmek istiyor musunuz?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.clearAllUserData();
              await UserProfileService.instance.resetAllUserData();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.expenseRed,
                    content: Text('Tüm verileriniz ve hesabınız başarıyla sıfırlandı.'),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expenseRed, foregroundColor: Colors.white),
            child: const Text('Evet, Hepsini Sil', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _restoreFromJsonBackup() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Yedekten Geri Yükle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kopyaladığınız Paraİz yedek JSON metnini buraya yapıştırın:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 5,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '{\n  "app": "ParaIz (MoneyTrace)",\n  ...\n}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                try {
                  final parsed = _exportService.validateAndParseBackup(text);
                  await _repository.restoreVaultBackup(parsed);

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF10B981),
                        content: Text('Yedek başarıyla geri yüklendi! Verileriniz güncellendi.'),
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.expenseRed, content: Text('Geri yükleme hatası: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Geri Yükle'),
            ),
          ],
        );
      },
    );
  }
}
