// lib/core/services/backup_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/repositories/transaction_repository.dart';
import '../security/aes_cipher.dart';
import 'account_service.dart';
import 'data_changes.dart';
import 'data_export_service.dart';
import 'user_profile_service.dart';

/// Hesaba bağlı, otomatik, şifreli yedekleme.
///
/// NOT (SEC-03/PRIV-02 denetim notu): Bu "uçtan uca" şifreleme DEĞİLDİR — anahtar
/// sunucuda türetilir (aşağıda açıklanıyor), kullanıcının elinde/ezberinde bir parola
/// yoktur. `BACKUP_KEY_SECRET`'e ve veritabanına erişimi olan biri (proje sahibi,
/// servis rolü sızıntısı) veya geçerli bir oturum jetonu çalan biri yedeği çözebilir.
///
/// Kullanıcının hatırlaması gereken bir yedekleme parolası YOKTUR: şifreleme anahtarı
/// sunucudaki `backup-key` Edge Function'ından alınır. O fonksiyon anahtarı kullanıcı
/// kimliğinden (auth.users.id) HMAC-SHA256 ile deterministik türetir — hangi cihazdan,
/// hangi oturumdan istenirse istensin aynı kullanıcı için HER ZAMAN aynı 32 baytlık
/// anahtarı verir ve sunucuda hiçbir yerde saklamaz. İstemci bu anahtarı yalnız bellekte
/// (oturum boyunca) önbelleğe alır, diske YAZMAZ.
///
/// Sunucu yalnızca `vault_blobs.ciphertext` sütunundaki şifreli metni görür; PDF
/// orijinalleri bu yedeğe DAHİL DEĞİLDİR — yalnız ayrıştırılmış veri (hesap, işlem,
/// taksit, vergi, hedef, planlı ödeme, üye işyeri kuralı vb.) yedeklenir.
///
/// Şifreleme: mevcut `AesCipher.encryptVaultPayload`/`decryptVaultPayload` AYNEN kullanılır
/// (yeni bir şifreleme yazılmadı). Bu fonksiyonlar tek parça, kendi kendini tanımlayan bir
/// zarf döndürür (`PARAIZ-SEC-VAULT-V2:<base64 envelope>`; envelope içinde salt+iv+ciphertext+
/// mac birlikte, base64 olarak taşınır). `vault_blobs.nonce` sütunu bu yüzden BOŞ bırakılır
/// ('') — IV zaten zarfın içine gömülü; onu ayrıca ayrıştırıp ayrı bir sütuna yazmak,
/// AesCipher'ın iç formatıyla senkron kalması gereken ikinci bir kod yolu açardı.
class BackupService {
  BackupService._internal({
    Duration? debounce,
    Future<String?> Function()? fetchKeyOverride,
    void Function()? onBackupRun,
  })  : _debounceDuration = debounce ?? const Duration(seconds: 9),
        _fetchKeyOverride = fetchKeyOverride,
        _onBackupRun = onBackupRun;

  static final BackupService instance = BackupService._internal();

  /// Yalnız testler için: gerçek singleton'a (ve gerçek DataChanges/Supabase durumuna)
  /// dokunmadan, kısa debounce süresi ve/veya sahte bağımlılıklarla bağımsız bir örnek.
  @visibleForTesting
  factory BackupService.forTesting({
    Duration debounce = const Duration(milliseconds: 30),
    Future<String?> Function()? fetchKeyOverride,
    void Function()? onBackupRun,
  }) =>
      BackupService._internal(
        debounce: debounce,
        fetchKeyOverride: fetchKeyOverride,
        onBackupRun: onBackupRun,
      );

  static const String _table = 'vault_blobs';
  static const String _blobId = 'full_backup';

  final Duration _debounceDuration;
  final Future<String?> Function()? _fetchKeyOverride;
  final void Function()? _onBackupRun;

  Timer? _debounceTimer;
  String? _cachedKeyBase64;
  bool _listenerAttached = false;

  // Eşzamanlı backupNow() çağrılarını sıraya sokar: aynı anda iki yükleme başlamaz,
  // her çağrı bir öncekinin bitmesini bekleyip öyle çalışır.
  Future<void> _chain = Future<void>.value();

  /// DataChanges dinleyicisini kurar. Her veri değişikliğinde debounce ile backupNow() çağırır.
  /// Birden çok kez çağrılırsa dinleyici yalnız bir kez eklenir.
  Future<void> initialize() async {
    if (_listenerAttached) return;
    _listenerAttached = true;
    DataChanges.revision.addListener(_onDataChanged);
  }

  /// Yalnız testler için: dinleyiciyi kaldırır, bekleyen zamanlayıcıyı iptal eder.
  @visibleForTesting
  void dispose() {
    if (_listenerAttached) {
      DataChanges.revision.removeListener(_onDataChanged);
      _listenerAttached = false;
    }
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void _onDataChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      unawaited(backupNow());
    });
  }

  /// Yeni oturumda (farklı hesap ya da çıkış) önceki kullanıcının anahtarını yanlışlıkla
  /// yeniden kullanmamak için bellekteki önbelleği temizler. Diskte zaten bir şey tutulmuyor.
  void clearCachedKey() {
    _cachedKeyBase64 = null;
  }

  /// Bekleyen bir debounce zamanlayıcısı varsa iptal eder; dinleyici (initialize) etkilenmez.
  /// ARCH-03 denetim notu: hesap değişimi/çıkış/sıfırlama gibi oturum sınırı geçişlerinden
  /// hemen önce çağrılır ki ÖNCEKİ hesabın verisiyle kurulmuş bekleyen bir yedekleme, geçişten
  /// sonra yanlış hesaba/duruma karşı tetiklenmesin. (hasLocalFinancialData() kontrolü zaten
  /// boş veri yüklemesini engelliyor; bu, aynı sorunu kaynağında da kapatır.)
  void cancelPendingDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Yerel veri sahibi bilinmiyorsa (eski kurulum, henüz sahip dosyası yazılmamış) yüklemeye izin
  /// verilir; sahibi biliniyor ve oturumdaki hesaptan FARKLIYSA yükleme yapılmaz.
  @visibleForTesting
  static bool mayUploadFor({required String? localOwnerId, required String sessionUserId}) =>
      localOwnerId == null || localOwnerId.isEmpty || localOwnerId == sessionUserId;

  Future<String?> _fetchKey() async {
    if (_fetchKeyOverride != null) return _fetchKeyOverride!();
    if (_cachedKeyBase64 != null) return _cachedKeyBase64;

    final client = AccountService.instance.signedInClient;
    if (client == null) return null;
    try {
      final res = await client.functions.invoke('backup-key', method: HttpMethod.post);
      final data = res.data;
      if (data is Map && data['keyBase64'] is String) {
        _cachedKeyBase64 = data['keyBase64'] as String;
        return _cachedKeyBase64;
      }
      debugPrint('backup-key: beklenmedik yanıt biçimi: ${data.runtimeType}');
      return null;
    } on FunctionException catch (e) {
      // 401 (oturum geçersiz) / 503 (sunucu yapılandırma hatası) dahil: sessizce null dön.
      debugPrint('backup-key alınamadı: ${e.status} ${e.details}');
      return null;
    } catch (e) {
      debugPrint('backup-key alınamadı: $e');
      return null;
    }
  }

  /// Telefondaki tüm finansal veriyi (PDF orijinalleri HARİÇ) şifreleyip sunucuya yükler.
  /// Oturum yoksa ya da anahtar alınamazsa sessizce çıkar (hata fırlatmaz).
  ///
  /// [force] çağıranın (ör. signOut) debounce'u beklemeden hemen bir yedekleme istediğini
  /// belirtir; kilit/sıralama mekanizması her durumda aynıdır (bu çağrı da sıraya girer).
  Future<void> backupNow({bool force = false}) {
    final run = _chain.then((_) => _backupNowInner());
    // Bu adım hata verse bile zincir devam etsin: bir sonraki backupNow() çağrısı
    // önceki hatadan etkilenmeden sırasını beklemeye devam eder.
    _chain = run.catchError((_) {});
    return run;
  }

  Future<void> _backupNowInner() async {
    _onBackupRun?.call();

    final client = AccountService.instance.signedInClient;
    final user = AccountService.instance.currentUser;
    if (client == null || user == null) return;

    // Telefondaki veri BAŞKA bir hesaba aitse (farklı hesapla giriş → "vazgeç" → signOut'taki
    // zorunlu yedek ya da onay ekranı açıkken tetiklenen debounce), o veri bu hesabın kasasına
    // yüklenmemeli: hem önceki hesabın verisi sızar hem bu hesabın gerçek yedeği ezilir.
    final localOwner = await UserProfileService.instance.localDataOwnerId();
    if (!mayUploadFor(localOwnerId: localOwner, sessionUserId: user.id)) {
      debugPrint('Otomatik yedekleme atlandı: telefondaki veri oturumdaki hesaba ait değil.');
      return;
    }

    // ARCH-03 denetim notu: telefonda hiç finansal veri yoksa (hesap değişimi/sıfırlama akışı
    // sırasında wipeLocalData() ile restoreIfEmpty() arasındaki kısa pencere dahil) BOŞ bir
    // yedek göndermeyiz — yoksa az önce sıfırlanan telefon, hesabın sunucudaki GERÇEK yedeğini
    // ezer. restoreIfEmpty() zaten simetrik olarak var olan yerel veriyi asla ezmiyor.
    if (!await UserProfileService.instance.hasLocalFinancialData()) {
      debugPrint('Otomatik yedekleme atlandı: telefonda finansal veri yok (boş yedek buluttakini ezmez).');
      return;
    }

    final keyBase64 = await _fetchKey();
    if (keyBase64 == null) return;

    try {
      final raw = await TransactionRepository().getAllDataForExport();
      List<Map<String, dynamic>> listOf(String key) =>
          (raw[key] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

      final extras = <String, List<Map<String, dynamic>>>{
        for (final t in TransactionRepositoryBackup.extraTables) t: listOf(t),
      };

      final json = DataExportService.instance.createFullVaultBackupJson(
        accounts: listOf('accounts'),
        statements: listOf('statements'),
        transactions: listOf('transactions'),
        installments: listOf('installments'),
        taxes: listOf('tax_deductions'),
        extras: extras,
      );

      final envelope = AesCipher.encryptVaultPayload(plainText: json, password: keyBase64);

      await client.from(_table).upsert(
        {
          'user_id': user.id,
          'blob_id': _blobId,
          'ciphertext': envelope,
          // IV zaten zarfın içinde (bkz. sınıf başı not) — ayrı bir nonce'a gerek yok.
          'nonce': '',
          'version': 2,
          'size_bytes': envelope.length,
        },
        onConflict: 'user_id,blob_id',
      );
    } catch (e) {
      debugPrint('Otomatik yedekleme başarısız: ${kDebugMode ? e : e.runtimeType}');
    }
  }

  /// Yerelde finansal veri YOKSA (taze cihaz ya da az önce wipeLocalData çalıştı) sunucudaki
  /// şifreli yedeği indirip geri yükler. Var olan yerel veriyi ASLA ezmez — her zaman önce
  /// yerel veri kontrolü yapılır ve varsa hiçbir ağ çağrısı yapılmadan false dönülür.
  Future<bool> restoreIfEmpty() async {
    if (await UserProfileService.instance.hasLocalFinancialData()) return false;

    final client = AccountService.instance.signedInClient;
    final user = AccountService.instance.currentUser;
    if (client == null || user == null) return false;

    final keyBase64 = await _fetchKey();
    if (keyBase64 == null) return false;

    try {
      final row = await client
          .from(_table)
          .select('ciphertext')
          .eq('user_id', user.id)
          .eq('blob_id', _blobId)
          .maybeSingle();
      final envelope = row?['ciphertext'] as String?;
      if (envelope == null || envelope.isEmpty) return false;

      final data =
          DataExportService.instance.validateAndParseBackup(envelope, password: keyBase64);
      await TransactionRepository().restoreVaultBackup(data);
      return true;
    } catch (e) {
      // Çözülmüş JSON'daki FormatException mesajı kaynak metinden kesit içerir: yalnız tür yazılır.
      debugPrint('Sunucu yedeği geri yüklenemedi: ${kDebugMode ? e : e.runtimeType}');
      return false;
    }
  }
}
