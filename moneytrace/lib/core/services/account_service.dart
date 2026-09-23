import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'user_profile_service.dart';

/// Kullanıcıya gösterilecek hesap hatası (Türkçe mesaj).
class AccountException implements Exception {
  final String message;
  const AccountException(this.message);
  @override
  String toString() => message;
}

/// Supabase hesabı: e-postaya gelen kodla kayıt / giriş (şifre yok).
///
/// Finansal veri buradan sunucuya GİTMEZ; hesap yalnızca kimlik içindir.
/// Şifreli yedek (vault) ayrı bir katmanda gelecek (GERI_BILDIRIM E4).
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  bool _ready = false;
  bool _googleReady = false;

  /// Uygulama açılışında bir kez. Ağ gerektirmez; oturum cihazdan yüklenir.
  Future<void> initialize() async {
    if (_ready) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _ready = true;
    } catch (e) {
      debugPrint('Supabase başlatılamadı: $e');
    }
  }

  SupabaseClient get _client {
    if (!_ready) {
      throw const AccountException(
          'Hesap servisi başlatılamadı. Uygulamayı yeniden aç.');
    }
    return Supabase.instance.client;
  }

  User? get currentUser =>
      _ready ? Supabase.instance.client.auth.currentUser : null;
  bool get isSignedIn => currentUser != null;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static bool isValidEmail(String email) => _emailRe.hasMatch(email.trim());

  /// E-postaya giriş kodu gönderir. [createUser] false ise yalnızca kayıtlı hesaba gönderir.
  Future<void> sendCode(String email,
      {required bool createUser, String? fullName}) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim().toLowerCase(),
        shouldCreateUser: createUser,
        data: createUser && fullName != null ? {'full_name': fullName} : null,
      );
    } on AuthException catch (e) {
      throw AccountException(_mapAuthError(e, createUser: createUser));
    } catch (e) {
      throw const AccountException(
          'Kod gönderilemedi. İnternet bağlantını kontrol edip tekrar dene.');
    }
  }

  /// Kodu doğrular; başarılıysa yerel profili hesapla eşler ve döner.
  Future<UserProfile> verifyCode(String email, String code,
      {String? fullName}) async {
    final AuthResponse res;
    try {
      res = await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: code.trim(),
        type: OtpType.email,
      );
    } on AuthException catch (e) {
      throw AccountException(_mapAuthError(e, createUser: false));
    } catch (e) {
      throw const AccountException(
          'Kod doğrulanamadı. İnternet bağlantını kontrol edip tekrar dene.');
    }
    final user = res.user;
    if (user == null) {
      throw const AccountException('Kod doğrulanamadı. Yeni kod iste.');
    }

    return _saveLocalProfile(user,
        fallbackEmail: email.trim().toLowerCase(), name: fullName);
  }

  /// Google hesabıyla giriş/kayıt (tek adım, kod yok). İptal edilirse null döner.
  Future<UserProfile?> signInWithGoogle() async {
    final client = _client;
    final GoogleSignInAccount account;
    try {
      final google = GoogleSignIn.instance;
      if (!_googleReady) {
        await google.initialize(
            serverClientId: SupabaseConfig.googleWebClientId);
        _googleReady = true;
      }
      account =
          await google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      debugPrint('Google girişi hatası: ${e.code} ${e.description}');
      throw const AccountException(
          'Google ile giriş yapılamadı. Bu cihazda bir Google hesabı olduğundan emin ol.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AccountException('Google kimlik doğrulaması alınamadı.');
    }
    final AuthResponse res;
    try {
      res = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } on AuthException catch (e) {
      throw AccountException(_mapAuthError(e, createUser: true));
    } catch (_) {
      throw const AccountException(
          'Giriş tamamlanamadı. İnternet bağlantını kontrol edip tekrar dene.');
    }
    final user = res.user;
    if (user == null) {
      throw const AccountException('Google ile giriş tamamlanamadı.');
    }
    return _saveLocalProfile(user,
        fallbackEmail: account.email, name: account.displayName);
  }

  Future<UserProfile> _saveLocalProfile(User user,
      {required String fallbackEmail, String? name}) async {
    var displayName = name?.trim() ?? '';
    if (displayName.isEmpty) displayName = await _remoteDisplayName(user) ?? '';
    if (displayName.isEmpty) {
      displayName = (user.email ?? fallbackEmail).split('@').first;
    }
    final existing = UserProfileService.instance.profile;
    final profile = UserProfile(
      id: user.id,
      name: displayName,
      email: user.email ?? fallbackEmail,
      currency: existing?.currency ?? 'TRY',
      monthlyBudgetCents: existing?.monthlyBudgetCents ?? 0,
      joinedAt: existing?.joinedAt ?? DateTime.now(),
    );
    await UserProfileService.instance.saveProfile(profile);
    return profile;
  }

  Future<String?> _remoteDisplayName(User user) async {
    final meta = user.userMetadata;
    final fromMeta = (meta?['full_name'] ?? meta?['name']) as String?;
    if (fromMeta != null && fromMeta.trim().isNotEmpty) return fromMeta.trim();
    try {
      final row = await _client
          .from('profiles')
          .select('display_name')
          .eq('user_id', user.id)
          .maybeSingle();
      return row?['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Hesabı sunucudan kalıcı olarak siler (profil, şifreli yedek, cihaz kayıtları dahil).
  /// Oturum yoksa bir şey yapmaz. Başarısız olursa [AccountException] fırlatır;
  /// çağıran taraf cihazdaki verileri silmeden önce bunu beklemelidir.
  Future<void> deleteAccount() async {
    if (!isSignedIn) return;
    try {
      await _client.functions.invoke('delete-account', method: HttpMethod.post);
    } on FunctionException catch (e) {
      debugPrint('Hesap silinemedi: ${e.status} ${e.details}');
      throw const AccountException(
          'Hesap sunucudan silinemedi. İnternet bağlantını kontrol edip tekrar dene.');
    } catch (_) {
      throw const AccountException(
          'Hesap sunucudan silinemedi. İnternet bağlantını kontrol edip tekrar dene.');
    }
    await signOut();
  }

  Future<void> signOut() async {
    if (!_ready) return;
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Oturum kapatılamadı: $e');
    }
  }

  String _mapAuthError(AuthException e, {required bool createUser}) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'otp_expired' ||
        msg.contains('expired') ||
        msg.contains('invalid')) {
      return 'Kod hatalı veya süresi dolmuş. Yeni kod iste.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        e.statusCode == '429') {
      return 'Çok sık kod istendi. Birkaç dakika sonra tekrar dene.';
    }
    if (!createUser &&
        (code == 'otp_disabled' ||
            code == 'user_not_found' ||
            msg.contains('signups not allowed'))) {
      return 'Bu e-postayla kayıtlı hesap bulunamadı. Önce kayıt ol.';
    }
    if (code == 'email_address_invalid' || msg.contains('email address')) {
      return 'E-posta adresi geçersiz görünüyor.';
    }
    return 'İşlem tamamlanamadı: ${e.message}';
  }
}
