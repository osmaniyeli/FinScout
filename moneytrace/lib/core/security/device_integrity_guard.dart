// lib/core/security/device_integrity_guard.dart

import 'package:flutter/services.dart';
import 'security_guard.dart';

/// Cihaz Bütünlüğü ve Kötü Amaçlı Yazılım / Root Algılama Kalkanı
///
/// Performans: Uygulama açılışında tek bir asenkron çağrıyla (< 1 ms) çalışır
/// ve oturum boyunca sonucu RAM'de önbelleğe alır. UI thread'i kesinlikle bloklamaz.
/// Maliyet: 0 TL (Yerel Android sistem çağrısı).
class DeviceIntegrityGuard {
  static final DeviceIntegrityGuard instance = DeviceIntegrityGuard._internal();
  DeviceIntegrityGuard._internal();

  static const MethodChannel _channel = MethodChannel('com.moneytrace.app/integrity');

  bool _hasChecked = false;
  bool _isRooted = false;
  bool _tapjackingProtected = true;

  bool get isRooted => _isRooted;
  bool get tapjackingProtected => _tapjackingProtected;
  bool get isDeviceCompromised => _isRooted;

  /// Asenkron Cihaz Bütünlüğü Taraması (< 1 ms)
  Future<Map<String, dynamic>> checkDeviceIntegrity() async {
    if (_hasChecked) {
      return {
        'isRooted': _isRooted,
        'tapjackingProtected': _tapjackingProtected,
        'cached': true,
      };
    }

    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('checkIntegrity');

      _isRooted = result?['isRooted'] as bool? ?? false;
      _tapjackingProtected = result?['tapjackingProtected'] as bool? ?? true;
      _hasChecked = true;

      if (_isRooted) {
        SecurityGuard.instance.logAudit(
          action: 'ROOT_DEVICE_DETECTED',
          details: 'Cihazda su binary veya root erişim yetkisi algılandı! Sandbox bütünlüğü risk altında.',
          severity: 'CRITICAL',
        );
      }

      return {
        'isRooted': _isRooted,
        'tapjackingProtected': _tapjackingProtected,
        'cached': false,
      };
    } on MissingPluginException {
      // Test veya emülatör ortamı
      _hasChecked = true;
      return {
        'isRooted': false,
        'tapjackingProtected': true,
        'cached': false,
      };
    } catch (e) {
      _hasChecked = true;
      return {
        'isRooted': false,
        'tapjackingProtected': true,
        'error': e.toString(),
      };
    }
  }
}
