// lib/core/widgets/remote_feature_gate.dart

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../config/remote_config_service.dart';

/// Bir modülü uzaktan şaltere (Kill-Switch) bağlayan koruma kalkanı.
/// Modül aktifse [child] içeriğini gösterir.
/// Modül uzaktan kapatılmışsa şık bir bakım kartı gösterir, uygulamanın çökmesini engeller.
class RemoteFeatureGate extends StatelessWidget {
  final String moduleKey;
  final Widget child;
  final Widget? fallbackWidget;

  const RemoteFeatureGate({
    Key? key,
    required this.moduleKey,
    required this.child,
    this.fallbackWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = RemoteConfigService.instance.isModuleActive(moduleKey);

    if (isActive) {
      return child;
    }

    if (fallbackWidget != null) {
      return fallbackWidget!;
    }

    final title = RemoteConfigService.instance.getMaintenanceTitle(moduleKey);
    final message = RemoteConfigService.instance.getMaintenanceMessage(moduleKey);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Icon(Icons.build_circle_rounded, size: 36, color: Color(0xFFEA580C)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Diğer tüm özellikleriniz aktif ve güvende',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
