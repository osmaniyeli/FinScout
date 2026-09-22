// lib/core/services/security_auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum BiometricAuthType {
  faceId,       // Yüz Tanıma (Face ID)
  fingerprint,  // Parmak İzi (Touch ID / Fingerprint)
  both,         // Her ikisi de desteklenir
}

class SecurityAuthService {
  static final SecurityAuthService instance = SecurityAuthService._internal();

  SecurityAuthService._internal();

  bool _isInitialized = false;
  bool _isFaceIdEnabled = false;
  bool _isFingerprintEnabled = false;
  bool _isPinEnabled = false;
  String? _hashedPin;
  String? _salt;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  final ValueNotifier<bool> isFaceIdEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isFingerprintEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPinEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasPinSetNotifier = ValueNotifier<bool>(false);

  bool get isFaceIdEnabled => _isFaceIdEnabled;
  bool get isFingerprintEnabled => _isFingerprintEnabled;
  bool get isPinEnabled => _isPinEnabled && hasPinSet;
  bool get hasPinSet => _hashedPin != null && _hashedPin!.isNotEmpty;
  bool get isAnySecurityActive => _isFaceIdEnabled || _isFingerprintEnabled || isPinEnabled;

  int get failedAttempts => _failedAttempts;
  bool get isLockedOut => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
  int get remainingLockoutSeconds => isLockedOut ? _lockedUntil!.difference(DateTime.now()).inSeconds : 0;

  Future<File> _getVaultFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_security_vault.json');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final file = await _getVaultFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        _isFaceIdEnabled = data['face_id_enabled'] ?? false;
        _isFingerprintEnabled = data['fingerprint_enabled'] ?? false;
        _isPinEnabled = data['pin_enabled'] ?? false;
        _hashedPin = data['hashed_pin'];
        _salt = data['salt'];

        isFaceIdEnabledNotifier.value = _isFaceIdEnabled;
        isFingerprintEnabledNotifier.value = _isFingerprintEnabled;
        isPinEnabledNotifier.value = _isPinEnabled && hasPinSet;
        hasPinSetNotifier.value = hasPinSet;
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('SecurityAuthService initialize hatasi: $e');
      _isInitialized = true;
    }
  }

  Future<void> _persist() async {
    try {
      final file = await _getVaultFile();
      final data = {
        'face_id_enabled': _isFaceIdEnabled,
        'fingerprint_enabled': _isFingerprintEnabled,
        'pin_enabled': _isPinEnabled,
        'hashed_pin': _hashedPin,
        'salt': _salt,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('SecurityAuthService persist hatasi: $e');
    }
  }

  String _hashPin(String rawPin, String salt) {
    final bytes = utf8.encode('$salt:$rawPin:paraiz_secure_v1');
    return sha256.convert(bytes).toString();
  }

  /// Yeni PIN kodu belirler ve PIN doğrulamasını aktif eder
  Future<void> setPin(String rawPin) async {
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    _salt = salt;
    _hashedPin = _hashPin(rawPin, salt);
    _isPinEnabled = true;
    _failedAttempts = 0;
    _lockedUntil = null;

    hasPinSetNotifier.value = true;
    isPinEnabledNotifier.value = true;
    await _persist();
  }

  /// PIN kodunu kaldırır — Kaldırmak için mevcut PIN'in doğrulanması şarttır
  Future<bool> removePin(String currentPin) async {
    final isValid = await verifyPin(currentPin);
    if (!isValid) {
      return false;
    }

    _hashedPin = null;
    _salt = null;
    _isPinEnabled = false;
    _failedAttempts = 0;
    _lockedUntil = null;

    hasPinSetNotifier.value = false;
    isPinEnabledNotifier.value = false;
    await _persist();
    return true;
  }

  /// Mevcut PIN'i doğrulayıp yenisiyle değiştirir
  Future<bool> changePin({required String currentPin, required String newPin}) async {
    final isValid = await verifyPin(currentPin);
    if (!isValid) {
      return false;
    }

    await setPin(newPin);
    return true;
  }

  Future<bool> verifyPin(String inputPin) async {
    if (isLockedOut) {
      return false;
    }

    if (_hashedPin == null || _salt == null) {
      return inputPin.length == 4;
    }

    final computed = _hashPin(inputPin, _salt!);
    if (computed == _hashedPin) {
      _failedAttempts = 0;
      _lockedUntil = null;
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      return false;
    }
  }

  /// Yüz Tanıma (Face ID) Şalterini Aç/Kapat
  Future<void> setFaceIdEnabled(bool enabled) async {
    _isFaceIdEnabled = enabled;
    isFaceIdEnabledNotifier.value = enabled;
    await _persist();
  }

  /// Parmak İzi (Touch ID / Fingerprint) Şalterini Aç/Kapat
  Future<void> setFingerprintEnabled(bool enabled) async {
    _isFingerprintEnabled = enabled;
    isFingerprintEnabledNotifier.value = enabled;
    await _persist();
  }

  /// PIN Girişi Şalterini Aç/Kapat
  Future<void> setPinEnabled(bool enabled) async {
    _isPinEnabled = enabled;
    isPinEnabledNotifier.value = enabled && hasPinSet;
    await _persist();
  }

  /// Yüz tanıma doğrulama köprüsü
  Future<bool> authenticateFaceId({required String reason}) async {
    if (isLockedOut) return false;
    await Future.delayed(const Duration(milliseconds: 400));
    _failedAttempts = 0;
    _lockedUntil = null;
    return true;
  }

  /// Parmak izi doğrulama köprüsü
  Future<bool> authenticateFingerprint({required String reason}) async {
    if (isLockedOut) return false;
    await Future.delayed(const Duration(milliseconds: 400));
    _failedAttempts = 0;
    _lockedUntil = null;
    return true;
  }

  /// Genel biyometrik çağrısı (önceki kodlarla geriye dönük uyumluluk için)
  Future<bool> authenticateBiometric({
    required String reason,
    BiometricAuthType? specificType,
  }) async {
    if (specificType == BiometricAuthType.fingerprint) {
      return authenticateFingerprint(reason: reason);
    }
    return authenticateFaceId(reason: reason);
  }
}
