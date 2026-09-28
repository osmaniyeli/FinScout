import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfrx/pdfrx.dart' show pdfrxFlutterInitialize;
import 'core/config/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/localization/app_content_service.dart';
import 'core/services/user_profile_service.dart';
import 'core/services/security_auth_service.dart';
import 'core/services/account_service.dart';
import 'core/services/backup_service.dart';
import 'core/parser/enrichment/category_engine.dart';
import 'core/services/notification_service.dart';
import 'core/services/push_service.dart';
import 'features/subscription/services/subscription_service.dart';
import 'core/database/repositories/transaction_repository.dart';
import 'core/widgets/fintech/fintech_components.dart';
import 'features/navigation/main_navigation_scaffold.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

/// Ekran değişse de alttaki bildirimin (SnackBar) kaybolmaması için uygulama düzeyinde messenger.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // İlk kare için gerekenler birbirinden bağımsız: sırayla değil birlikte beklenir.
  // (Her biri hatayı kendi içinde yakalar; Future.wait hiçbir zaman hata fırlatmaz.)
  await Future.wait<void>([
    RemoteConfigService.instance.loadFromAsset(),
    // Profil: açılışta Onboarding mi Ana sayfa mı gösterileceğini belirler
    UserProfileService.instance.load(),
    // PIN kilidi: ilk karede kilit ekranı gerekip gerekmediğini belirler
    SecurityAuthService.instance.initialize(),
    // Hesap (Supabase Auth): oturum cihazdan yüklenir, ağ beklemez
    AccountService.instance.initialize(),
  ]);
  // Canlı içerik/metin (CMS): önceden çekilmiş önbellek varsa hemen uygulanır (yalnız yerel
  // dosya okuması, ağ beklemez). AccountService.initialize() bittiği için Supabase artık hazır.
  await AppContentService.instance.loadCached();
  // PDF motoru (PDFium) — ekstreler tamamen cihaz üzerinde okunur
  pdfrxFlutterInitialize();
  // Üye işyeri sözlüğü yalnız ekstre içe aktarırken gerekir: ilk kareyi bekletmeden arka planda
  // (ayrı isolate'te) çözülür; içe aktarma başlamadan önce StatementOrchestrator bitmesini bekler.
  unawaited(_loadMerchantDictionary());
  runApp(const FinScoutApp());
  // Açılışı bekletmeden: kart son ödeme ve ekstre talimatı hatırlatıcılarını güncelle
  unawaited(syncPaymentReminders());
  // Kendi hesaplar arası transferleri (ör. Yapı Kredi → Enpara) geriye dönük eşleştir: kullanıcı
  // hesaplarını farklı oturumlarda tek tek yüklediyse, ikinci hesap gelince ilki de düzelir.
  // Tek seferlik göç değildir; her açılışta tekrar çalışır (bkz. TransactionRepository.reconcileOwnTransfers).
  unawaited(_reconcileOwnTransfersAtStartup());
  // Google Play Billing: satın alma akışını dinle, kayıtlı yetkiyi mağazayla doğrula
  unawaited(SubscriptionService.instance.initialize());
  // Firebase push (yönetici duyuruları); google-services.json yoksa sessizce kapalı
  unawaited(PushService.instance.initialize());
  // Hesaba bağlı otomatik yedekleme: DataChanges dinleyicisini kurar (her değişiklikte debounce
  // ile arka planda yedekler). Ağ/oturum gerektirmez; oturum yoksa backupNow kendi içinde çıkar.
  unawaited(BackupService.instance.initialize());
  // Yönetim panelinden düzenlenen canlı metinler: arka planda bir kerelik çekilir, AppStrings'e
  // uygulanır ve önbelleğe yazılır. Hata (ağ yok, tablo boş) sessizce yutulur.
  unawaited(AppContentService.instance.refreshFromSupabase());
}

/// Ekstrelerden okunan yaklaşan ödemeler için hatırlatıcıları (yeniden) kurar. Hata uygulamayı etkilemez.
Future<void> syncPaymentReminders() async {
  try {
    await NotificationService.instance.initialize();
    final upcoming = await TransactionRepository().getUpcomingPayments();
    await NotificationService.instance.syncUpcomingPayments(upcoming);
  } catch (e) {
    debugPrint('Ödeme hatırlatıcıları kurulamadı: $e');
  }
}

/// Açılışta, kendi hesapları arası transferleri (ör. Yapı Kredi'den Enpara'ya) geriye dönük eşleştirir.
/// Tek seferlik göç değil: her açılışta çalışır, böylece kullanıcı ikinci hesabını sonradan
/// yüklediğinde ilk hesaptaki eski kayıt da düzelir. Hata uygulamayı etkilemez.
Future<void> _reconcileOwnTransfersAtStartup() async {
  try {
    final pairs = await TransactionRepository().reconcileOwnTransfers();
    if (pairs > 0) {
      debugPrint('Kendi hesap transferi eşleştirildi: $pairs çift');
    }
  } catch (e) {
    debugPrint('Kendi hesap transferi eşleştirmesi başarısız: $e');
  }
}

/// Üye işyeri → sektör sözlüğü. Dosya yoksa kategori motoru yerleşik kurallarla çalışır.
Future<void> _loadMerchantDictionary() =>
    CategoryEngine.instance.loadDictionaryInBackground(() =>
        rootBundle.loadString('assets/dictionaries/merchant_sectors_tr.json'));

class FinScoutApp extends StatefulWidget {
  const FinScoutApp({super.key});

  @override
  State<FinScoutApp> createState() => _FinScoutAppState();
}

class _FinScoutAppState extends State<FinScoutApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!SecurityAuthService.instance.isAnySecurityActive) {
      _isUnlocked = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kilit yalnız uygulama gerçekten arka planda (paused) ≥30 sn kaldıysa devreye girer.
    // 'inactive' (bildirim perdesi, sistem diyaloğu) kilidi tetiklemez.
    if (state == AppLifecycleState.paused) {
      _pausedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedTime;
      // Kontrolden sonra sıfırlanır; yoksa sonraki her 'resumed'da kilit yeniden açılır (döngü).
      _pausedTime = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt).inSeconds >= 30 &&
          SecurityAuthService.instance.isAnySecurityActive &&
          _isUnlocked) {
        setState(() {
          _isUnlocked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppStrings.currentLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<UserProfile?>(
          valueListenable: UserProfileService.instance.profileNotifier,
          builder: (context, profile, _) {
            final hasProfile =
                profile != null && profile.name.trim().isNotEmpty;

            return MaterialApp(
              title: 'FinScout',
              scaffoldMessengerKey: appMessengerKey,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: hasProfile
                  ? const MainNavigationScaffold()
                  : OnboardingScreen(
                      onCompleted: () {
                        setState(() => _isUnlocked = true);
                        _announceNewAccount();
                        _announceRestoredBackup();
                      },
                    ),
              // Kilit Navigator'ın ÜSTÜNDE: açık alt sayfa, diyalog ya da itilmiş ekran da örtülür.
              builder: (context, child) => _wrapWithGuards(child!, hasProfile),
            );
          },
        );
      },
    );
  }

  /// Hesap yeni açıldıysa ana ekran geldikten sonra altta bir kez bildirim gösterir.
  void _announceNewAccount() {
    if (!AccountService.instance.lastSignInCreatedAccount) return;
    AccountService.instance.lastSignInCreatedAccount = false;
    final email = UserProfileService.instance.profile?.email ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Text(email.isEmpty
              ? 'Hesabın oluşturuldu.'
              : 'Hesabın oluşturuldu: $email'),
        ),
      );
    });
  }

  /// Girişte telefonda veri yoktu ve sunucudaki şifreli yedek geri yüklendiyse ana ekran
  /// geldikten sonra altta bir kez bildirim gösterir. _announceNewAccount ile aynı anda
  /// tetiklenmez: biri yeni hesap açılışını, diğeri var olan bir hesabın verisinin bu
  /// cihaza dönüşünü bildirir.
  void _announceRestoredBackup() {
    if (!AccountService.instance.lastSignInRestoredBackup) return;
    AccountService.instance.lastSignInRestoredBackup = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
          content: Text('Verilerin bu cihaza geri yüklendi.'),
        ),
      );
    });
  }

  /// GEÇİCİ KAPALI (2026-09-27): PIN kilidi bazı kullanıcılarda siyah ekranda takılıp Ayarlar'a
  /// geri dönüşü engelliyor; kesin nedeni canlı cihazda doğrulanana kadar kilit hiç kimseyi
  /// bloklamasın diye devre dışı. SecurityAuthService ve AppLockScreen silinmedi; düzeltilip
  /// test edilince bu bayrak true yapılacak. Ayarlar'da yeni PIN oluşturma da ayrıca kapatıldı.
  ///
  /// NOT (2026-09-29 doğrulaması, [A1]): 24 Eylül denetiminde kilidin Navigator'ın ALTINDA kalıp
  /// itilmiş ekranları (Profil vb.) kapsamadığı tespit edilmişti. O sorun artık YOK: kilit,
  /// MaterialApp.builder üzerinden (bkz. aşağıdaki `builder:` ve _wrapWithGuards) Navigator'ın
  /// KENDİSİNİN ÜSTÜNDE bir Stack katmanı olarak kuruluyor — bu bayrak tekrar true yapıldığında
  /// itilmiş/push edilmiş her ekran da otomatik örtülür, ayrıca bir değişiklik gerekmez.
  static const bool _kPinLockEnforced = false;

  Widget _wrapWithGuards(Widget child, bool hasProfile) {
    final shouldLock = _kPinLockEnforced &&
        hasProfile &&
        SecurityAuthService.instance.isAnySecurityActive &&
        !_isUnlocked;

    return Stack(
      children: [
        child,
        if (shouldLock)
          Positioned.fill(
            // Kilit ekranının kendi Navigator'ı olsun (diyalog/overlay gerektiren bileşenler için)
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => AppLockScreen(
                  onUnlocked: () => setState(() => _isUnlocked = true),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
