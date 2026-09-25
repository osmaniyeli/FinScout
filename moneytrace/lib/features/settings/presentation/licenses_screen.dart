import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Uygulamanın doğrudan kullandığı açık kaynak paketler (pubspec.yaml `dependencies`).
/// Lisans türleri paketlerin kendi LICENSE dosyalarından alınmıştır; paket eklenip
/// çıkarıldığında bu liste de güncellenmelidir.
class _OpenSourcePackage {
  final String name;
  final String license;
  final String description;

  const _OpenSourcePackage(this.name, this.license, this.description);
}

const List<_OpenSourcePackage> _packages = [
  _OpenSourcePackage('Flutter', 'BSD-3-Clause', 'Uygulama çatısı'),
  _OpenSourcePackage('fl_chart', 'MIT', 'Grafikler'),
  _OpenSourcePackage('google_fonts', 'BSD-3-Clause', 'Yazı tipleri'),
  _OpenSourcePackage('sqflite', 'BSD-2-Clause', 'Telefondaki veritabanı'),
  _OpenSourcePackage('path_provider', 'BSD-3-Clause', 'Dosya klasörlerine erişim'),
  _OpenSourcePackage('path', 'BSD-3-Clause', 'Dosya yolu işlemleri'),
  _OpenSourcePackage('file_picker', 'MIT', 'Ekstre dosyası seçme'),
  _OpenSourcePackage('crypto', 'BSD-3-Clause', 'Özet (hash) hesaplama'),
  _OpenSourcePackage('share_plus', 'BSD-3-Clause', 'Dosya paylaşma'),
  _OpenSourcePackage('url_launcher', 'BSD-3-Clause', 'Bağlantı açma'),
  _OpenSourcePackage('in_app_purchase', 'BSD-3-Clause', 'Google Play abonelikleri'),
  _OpenSourcePackage('in_app_purchase_android', 'BSD-3-Clause', 'Google Play abonelikleri'),
  _OpenSourcePackage('flutter_secure_storage', 'BSD-3-Clause', 'Güvenli depolama (PIN)'),
  _OpenSourcePackage('flutter_local_notifications', 'BSD-3-Clause', 'Hatırlatma bildirimleri'),
  _OpenSourcePackage('timezone', 'BSD-2-Clause', 'Saat dilimi verisi'),
  _OpenSourcePackage('flutter_timezone', 'Apache-2.0', 'Telefonun saat dilimi'),
  _OpenSourcePackage('pdfrx', 'MIT', 'PDF ekstre okuma'),
  _OpenSourcePackage('pdfrx_engine', 'MIT', 'PDF ekstre okuma'),
  _OpenSourcePackage('supabase_flutter', 'MIT', 'Hesap ve oturum'),
  _OpenSourcePackage('google_sign_in', 'BSD-3-Clause', 'Google ile giriş'),
  _OpenSourcePackage('firebase_core', 'BSD-3-Clause', 'Bildirim altyapısı'),
  _OpenSourcePackage('firebase_messaging', 'BSD-3-Clause', 'Duyuru bildirimleri'),
];

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Açık kaynak lisansları',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'FinScout aşağıdaki açık kaynak yazılımları kullanır. Emeği geçenlere teşekkürler.',
            style: TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          for (final p in _packages)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(p.name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              subtitle: Text(p.description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              trailing: Text(p.license,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showLicensePage(
                  context: context, applicationName: 'FinScout'),
              child: const Text('Tüm üçüncü taraf lisans metinleri',
                  style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}
