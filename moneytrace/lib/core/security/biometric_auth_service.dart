// lib/core/security/biometric_auth_service.dart

import 'package:flutter/services.dart';
import 'security_guard.dart';

enum BiometricStatus {
  available,
  notEnrolled,
  notAvailable,
  disabledByPolicy,
}

/// Paraİz Biyometrik Kimlik Doğrulama Servisi (FaceID / TouchID / BiometricPrompt)
class BiometricAuthService {
  static final BiometricAuthService instance = BiometricAuthService._internal();
  BiometricAuthService._internal();

  static const MethodChannel _channel = MethodChannel('com.moneytrace.app/biometrics');

  bool _isBiometricLockEnabled = false;
  bool get isBiometricLockEnabled => _isBiometricLockEnabled;

  void setBiometricLockEnabled(bool enabled) {
    _isBiometricLockEnabled = enabled;
  }

  /// Cihazda biyometrik donanım ve parmak izi/yüz tanıma kaydı var mı kontrol eder
  Future<bool> canCheckBiometrics() async {
    try {
      final bool? canCheck = await _channel.invokeMethod<bool>('canCheckBiometrics');
      return canCheck ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Biyometrik Doğrulama İsteği Başlatır
  Future<bool> authenticate({
    String reason = 'Paraİz kasanıza erişmek için lütfen biyometrik doğrulama yapınız.',
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('authenticate', {
        'localizedReason': reason,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      SecurityGuard.instance.logAudit(
        action: 'BIOMETRIC_AUTH_FAILURE',
        details: 'Biyometrik doğrulama hatası: $e',
        severity: 'WARNING',
      );
      return false;
    }
  }

  /// PIN ile Güvenli Fallback Doğrulaması (Tuzlu HMAC-SHA256)
  bool authenticateWithPin({
    required String enteredPin,
    required String storedHash,
    required String salt,
  }) {
    return SecurityGuard.instance.verifyPinHash(
      enteredPin: enteredPin,
      storedHash: storedHash,
      salt: salt,
    );
  }
}
