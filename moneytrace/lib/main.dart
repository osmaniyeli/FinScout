// lib/main.dart

import 'package:flutter/material.dart';
import 'core/config/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_strings.dart';
import 'core/services/user_profile_service.dart';
import 'features/navigation/main_navigation_scaffold.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteConfigService.instance.loadFromAsset();
  await UserProfileService.instance.load();
  runApp(const MoneyTraceApp());
}

class MoneyTraceApp extends StatefulWidget {
  const MoneyTraceApp({Key? key}) : super(key: key);

  @override
  State<MoneyTraceApp> createState() => _MoneyTraceAppState();
}

class _MoneyTraceAppState extends State<MoneyTraceApp> {
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
              home: hasProfile
                  ? const MainNavigationScaffold()
                  : OnboardingScreen(
                      onCompleted: () {
                        setState(() {});
                      },
                    ),
            );
          },
        );
      },
    );
  }
}
