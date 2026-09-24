/// Supabase bağlantı bilgileri.
///
/// Publishable key istemcide bulunmak üzere tasarlanmıştır; erişim RLS ile
/// sınırlıdır. service_role / secret key ve veritabanı şifresi ASLA buraya
/// (veya repoya) girmez. Farklı ortam için `--dart-define` ile ezilebilir.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oudxswtadqurmlnvcjyc.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_z-4pVDjZcmzDM6n-uMrLuA_hrSLSGdp',
  );

  static const String projectRef = 'oudxswtadqurmlnvcjyc';

  /// Google Cloud "Web application" OAuth client ID. Google kimlik jetonu bu
  /// kitleye (aud) verilir; Supabase Google sağlayıcısında da aynı ID kayıtlı.
  /// Android client'ları (paket + SHA-1) ayrıca tanımlıdır, burada gerekmez.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '454506681574-mqon8e4h6n6jr1rst6ae477lgetskkd3.apps.googleusercontent.com',
  );
}
