// test/app_content_service_test.dart
//
// Canlı içerik/metin sistemi (CMS) — GÖREV 1: AppStrings.get(...) önce Supabase'den önceden
// çekilip yerelde önbelleklenmiş (paraiz_app_content_cache.json) değere bakmalı, o yoksa
// sabit kodlu Türkçe/İngilizce sözlüğe düşmeli. Bu test GERÇEK bir ağ çağrısı yapmaz: yalnız
// AppContentService.loadCached()'in dosya tabanlı önbelleği okuyup AppStrings'e uyguladığını,
// ve önbellek/veri yokken sabit koda düştüğünü doğrular (bkz. app_content_service.dart,
// app_strings.dart _overrides/applyOverrides).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/core/localization/app_content_service.dart';
import 'package:moneytrace/core/localization/app_strings.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_app_content_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    AppStrings.clearOverridesForTest();
    AppStrings.currentLocale.value = 'tr';
  });

  tearDown(() async {
    AppStrings.clearOverridesForTest();
    AppStrings.currentLocale.value = 'tr';
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
    }
  });

  group('AppContentService.loadCached — ağsız önbellek okuma', () {
    test('Önbellekte bir anahtar varsa AppStrings.get(...) onu döner (sabit kodun yerine geçer)',
        () async {
      final file = File('${tempDir.path}/paraiz_app_content_cache.json');
      await file.writeAsString(jsonEncode([
        {
          'key': 'nav_home',
          'tr': 'Panelim (yönetimden)',
          'en': 'My Panel (from admin)',
          'category': 'nav',
        },
      ]));

      await AppContentService.instance.loadCached();

      AppStrings.currentLocale.value = 'tr';
      expect(AppStrings.get('nav_home'), 'Panelim (yönetimden)');
      AppStrings.currentLocale.value = 'en';
      expect(AppStrings.get('nav_home'), 'My Panel (from admin)');
    });

    test('Önbellek dosyası yoksa sessizce hiçbir şey değişmez, sabit kod çalışır', () async {
      // Dosya hiç yazılmadı.
      await AppContentService.instance.loadCached();

      AppStrings.currentLocale.value = 'tr';
      expect(AppStrings.get('nav_home'), 'Ana Sayfa');
      AppStrings.currentLocale.value = 'en';
      expect(AppStrings.get('nav_home'), 'Home');
    });

    test('Önbellek dosyası bozuk JSON içerirse hata fırlatmaz, sabit koda düşer', () async {
      final file = File('${tempDir.path}/paraiz_app_content_cache.json');
      await file.writeAsString('{ this is not valid json ][');

      await expectLater(AppContentService.instance.loadCached(), completes);

      expect(AppStrings.get('nav_home'), 'Ana Sayfa');
    });

    test('Önbellekte olmayan bir anahtar için sabit koda düşülür (kısmi geçersiz kılma)',
        () async {
      final file = File('${tempDir.path}/paraiz_app_content_cache.json');
      await file.writeAsString(jsonEncode([
        {'key': 'nav_home', 'tr': 'Özel Ana Sayfa', 'en': 'Custom Home'},
      ]));

      await AppContentService.instance.loadCached();

      AppStrings.currentLocale.value = 'tr';
      // Geçersiz kılınan anahtar:
      expect(AppStrings.get('nav_home'), 'Özel Ana Sayfa');
      // Geçersiz kılınmayan başka bir anahtar hâlâ sabit koddan gelir:
      expect(AppStrings.get('nav_cashflow'), 'Cüzdan');
    });

    test('Asla boş metin göstermez: bilinmeyen anahtar kendi adını döner (son çare)', () {
      expect(AppStrings.get('hic_boyle_bir_anahtar_yok'), 'hic_boyle_bir_anahtar_yok');
    });
  });

  group('AppStrings.applyOverrides — girdi doğrulama', () {
    test('Eksik/boş tr ya da en alanı olan satır o dil için yok sayılır', () {
      AppStrings.applyOverrides([
        {'key': 'save', 'tr': '', 'en': 'Save (custom)'},
      ]);
      AppStrings.currentLocale.value = 'tr';
      // tr boş bırakıldığı için sabit koddaki 'Kaydet' hâlâ geçerli.
      expect(AppStrings.get('save'), 'Kaydet');
      AppStrings.currentLocale.value = 'en';
      expect(AppStrings.get('save'), 'Save (custom)');
    });

    test('key alanı olmayan satır atlanır, hata fırlatmaz', () {
      expect(() => AppStrings.applyOverrides([
            {'tr': 'x', 'en': 'y'},
            'not a map',
            42,
          ]), returnsNormally);
    });
  });
}
