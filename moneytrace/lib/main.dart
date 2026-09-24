import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfrx/pdfrx.dart' show pdfrxFlutterInitialize;
import 'core/config/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/services/user_profile_service.dart';
import 'core/services/security_auth_service.dart';
import 'core/services/account_service.dart';
import 'core/parser/enrichment/category_engine.dart';
import 'core/services/notification_service.dart';
import 'features/subscription/services/subscription_service.dart';
import 'core/database/repositories/transaction_repository.dart';
import 'core/widgets/fintech/fintech_components.dart';
import 'features/navigation/main_navigation_scaffold.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteConfigService.instance.loadFromAsset();
  await UserProfileService.instance.load();
  await SecurityAuthService.instance.initialize();
  // Hesap (Supabase Auth): oturum cihazdan yüklenir, ağ beklemez
  await AccountService.instance.initialize();
  // PDF motoru (PDFium) — ekstreler tamamen cihaz üzerinde okunur
  pdfrxFlutterInitialize();
  await _loadMerchantDictionary();
  runApp(const FinScoutApp());
  // Açılışı bekletmeden: kart son ödeme ve ekstre talimatı hatırlatıcılarını güncelle
  unawaited(syncPaymentReminders());
  // Google Play Billing: satın alma akışını dinle, kayıtlı yetkiyi mağazayla doğrula
  unawaited(SubscriptionService.instance.initialize());
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

/// Üye işyeri → sektör sözlüğü. Dosya yoksa kategori motoru yerleşik kurallarla çalışır.
Future<void> _loadMerchantDictionary() async {
  try {
    CategoryEngine.instance.loadDictionary(
      await rootBundle.loadString('assets/dictionaries/merchant_sectors_tr.json'),
    );
  } catch (_) {}
}

class FinScoutApp extends StatefulWidget {
  const FinScoutApp({Key? key}) : super(key: key);

  @override
  State<FinScoutApp> createState() => _FinScoutAppState();
}

class _FinScoutAppState extends State<FinScoutApp> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isPrivacyShieldActive = false;
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
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (!_isPrivacyShieldActive) {
        setState(() {
          _isPrivacyShieldActive = true;
        });
      }
      if (state == AppLifecycleState.paused) {
        _pausedTime = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isPrivacyShieldActive) {
        setState(() {
          _isPrivacyShieldActive = false;
        });
      }
      if (_pausedTime != null) {
        final elapsed = DateTime.now().difference(_pausedTime!).inSeconds;
        if (elapsed >= 30 && SecurityAuthService.instance.isAnySecurityActive) {
          setState(() {
            _isUnlocked = false;
          });
        }
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
            final hasProfile = profile != null && profile.name.trim().isNotEmpty;

            return MaterialApp(
              title: 'FinScout',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: hasProfile
                  ? const MainNavigationScaffold()
                  : OnboardingScreen(
                      onCompleted: () => setState(() => _isUnlocked = true),
                    ),
              // Kilit ve gizlilik kalkanı Navigator'ın ÜSTÜNDE: açık alt sayfa, diyalog ya da
              // itilmiş ekran da örtülür.
              builder: (context, child) => _wrapWithGuards(child!, hasProfile),
            );
          },
        );
      },
    );
  }

  Widget _wrapWithGuards(Widget child, bool hasProfile) {
    final shouldLock =
        hasProfile && SecurityAuthService.instance.isAnySecurityActive && !_isUnlocked;

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
        // Çift Katmanlı Ekran Gizlilik Kalkanı (Ekran Görüntüsü ve Önizleme Koruması)
        if (_isPrivacyShieldActive)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0C0E14),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 48),
                    SizedBox(height: 12),
                    Text(
                      'FinScout Güvenlik Kalkanı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Finansal Veri Gizliliği Korunuyor',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

