import 'package:flutter/material.dart';
import 'core/config/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/services/user_profile_service.dart';
import 'core/services/security_auth_service.dart';
import 'core/widgets/fintech/fintech_components.dart';
import 'features/navigation/main_navigation_scaffold.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteConfigService.instance.loadFromAsset();
  await UserProfileService.instance.load();
  await SecurityAuthService.instance.initialize();
  runApp(const MoneyTraceApp());
}

class MoneyTraceApp extends StatefulWidget {
  const MoneyTraceApp({Key? key}) : super(key: key);

  @override
  State<MoneyTraceApp> createState() => _MoneyTraceAppState();
}

class _MoneyTraceAppState extends State<MoneyTraceApp> with WidgetsBindingObserver {
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
              title: 'Paraİz - Harcama Zekası',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: _buildHome(hasProfile),
            );
          },
        );
      },
    );
  }

  Widget _buildHome(bool hasProfile) {
    if (!hasProfile) {
      return OnboardingScreen(
        onCompleted: () {
          setState(() {
            _isUnlocked = true;
          });
        },
      );
    }

    final isSecurityActive = SecurityAuthService.instance.isAnySecurityActive;
    final shouldLock = isSecurityActive && !_isUnlocked;

    return Stack(
      children: [
        const MainNavigationScaffold(),
        if (shouldLock)
          Positioned.fill(
            child: AppLockScreen(
              onUnlocked: () {
                setState(() {
                  _isUnlocked = true;
                });
              },
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
                      'Paraİz Güvenlik Kalkanı',
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

