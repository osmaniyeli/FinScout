// lib/main.dart

import 'package:flutter/material.dart';
import 'core/config/remote_config_service.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/main_navigation_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteConfigService.instance.loadFromAsset();
  runApp(const MoneyTraceApp());
}

class MoneyTraceApp extends StatelessWidget {
  const MoneyTraceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paraİz - Harcama Zekası',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScaffold(),
    );
  }
}
