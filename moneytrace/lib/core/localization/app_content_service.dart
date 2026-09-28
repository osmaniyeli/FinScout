// lib/core/localization/app_content_service.dart
//
// Canlı içerik/metin sisteminin (CMS) istemci ucu. Yönetim paneli, Supabase'deki
// `public.app_content` tablosuna (key/tr/en/category) satır yazar; bu servis o tabloyu
// okuyup AppStrings'in sabit kodlu sözlüğünü GEÇERSİZ KILAR (override) — asla yerini almaz.
// Ağ yoksa, satır çekilmemişse ya da Supabase henüz hazır değilse AppStrings.get() sessizce
// sabit kodlu Türkçe/İngilizce sözlüğe düşer; kullanıcı hiçbir zaman boş metin görmez.
//
// Dosya tabanlı önbellekleme deseni UserProfileService ile aynıdır (bkz. user_profile_service.dart
// _getStorageFile/_persist): uygulama belgeleri klasöründe düz bir JSON dosyası.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_strings.dart';

class AppContentService {
  AppContentService._internal();
  static final AppContentService instance = AppContentService._internal();

  Future<File> _cacheFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_app_content_cache.json');
  }

  /// Açılışta bir kerelik: daha önce çekilmiş içerik önbellekte varsa hemen uygular.
  /// Tamamen yerel bir dosya okuması; ağ ya da Supabase gerektirmez, hata fırlatmaz.
  Future<void> loadCached() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final rows = jsonDecode(content);
      if (rows is List) {
        AppStrings.applyOverrides(rows);
      }
    } catch (e) {
      debugPrint('AppContentService: önbellek okunamadı: $e');
    }
  }

  /// Arka planda `app_content` tablosunu çeker, AppStrings'e uygular ve önbelleğe yazar.
  /// Supabase henüz başlatılmadıysa, ağ yoksa ya da tablo boşsa sessizce hiçbir şey yapmaz —
  /// sabit kodlu sözlük her zaman çalışan bir yedek olarak kalır.
  Future<void> refreshFromSupabase() async {
    try {
      final rows = await Supabase.instance.client
          .from('app_content')
          .select('key, tr, en, category')
          .timeout(const Duration(seconds: 8));
      if (rows.isEmpty) return;
      AppStrings.applyOverrides(rows);
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(rows));
    } catch (e) {
      // Supabase henüz initialize edilmemiş olabilir (StateError) ya da ağ/DB hatası olabilir;
      // her iki durumda da sabit kodlu sözlük çalışmaya devam eder.
      debugPrint(
          'AppContentService: canlı içerik çekilemedi (sabit kodlu sözlük kullanılıyor): $e');
    }
  }
}
