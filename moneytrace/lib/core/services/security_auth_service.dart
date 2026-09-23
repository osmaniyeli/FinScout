// lib/core/services/security_auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../security/aes_cipher.dart';

enum BiometricAuthType {
  faceId,       // Yüz Tanıma (Face ID)
  fingerprint,  // Parmak İzi (Touch ID / Fingerprint)
  both,         // Her ikisi de desteklenir
}

/// Kasa kilidi: PIN + cihaz biyometrisi (Android BiometricPrompt / iOS LocalAuthentication).
/// Tüm ayarlar ve PIN hash'i Android Keystore / iOS Keychain destekli güvenli depoda tutulur.
class SecurityAuthService {
  static final SecurityAuthService instance = SecurityAuthService._internal();

  SecurityAuthService._internal();

  static const String _vaultKey = 'paraiz_security_vault_v2';
  static const int _pinIterations = 20000;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isInitialized = false;
  bool _isFaceIdEnabled = false;
  bool _isFingerprintEnabled = false;
  bool _isPinEnabled = false;
  String? _hashedPin;
  String? _salt;
  int _pinVersion = 2;
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

  /// v1 sürümündeki düz JSON kasa dosyası (yalnızca tek seferlik göç için okunur, sonra silinir)
  Future<File> _getLegacyVaultFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File('${docsDir.path}/paraiz_security_vault.json');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      Map<String, dynamic>? data;
      final stored = await _storage.read(key: _vaultKey);
      if (stored != null && stored.isNotEmpty) {
        data = jsonDecode(stored) as Map<String, dynamic>;
      } else {
        data = await _migrateLegacyVault();
      }

      if (data != null) {
        _isFaceIdEnabled = data['face_id_enabled'] ?? false;
        _isFingerprintEnabled = data['fingerprint_enabled'] ?? false;
        _isPinEnabled = data['pin_enabled'] ?? false;
        _hashedPin = data['hashed_pin'];
        _salt = data['salt'];
        _pinVersion = data['pin_version'] ?? 1;
        _failedAttempts = data['failed_attempts'] ?? 0;
        final lockedUntil = data['locked_until'] as String?;
        _lockedUntil = lockedUntil != null ? DateTime.tryParse(lockedUntil) : null;
      }
    } catch (e) {
      debugPrint('SecurityAuthService initialize hatasi: $e');
    }

    _syncNotifiers();
    _isInitialized = true;
  }

  Future<Map<String, dynamic>?> _migrateLegacyVault() async {
    try {
      final file = await _getLegacyVaultFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data['pin_version'] = 1; // Eski SHA-256 hash; ilk başarılı girişte PBKDF2'ye yükseltilir
      await _storage.write(key: _vaultKey, value: jsonEncode(data));
      await file.delete();
      return data;
    } catch (e) {
      debugPrint('SecurityAuthService legacy migrate hatasi: $e');
      return null;
    }
  }

  void _syncNotifiers() {
    isFaceIdEnabledNotifier.value = _isFaceIdEnabled;
    isFingerprintEnabledNotifier.value = _isFingerprintEnabled;
    isPinEnabledNotifier.value = _isPinEnabled && hasPinSet;
    hasPinSetNotifier.value = hasPinSet;
  }

  Future<void> _persist() async {
    try {
      final data = {
        'face_id_enabled': _isFaceIdEnabled,
        'fingerprint_enabled': _isFingerprintEnabled,
        'pin_enabled': _isPinEnabled,
        'hashed_pin': _hashedPin,
        'salt': _salt,
        'pin_version': _pinVersion,
        'failed_attempts': _failedAttempts,
        'locked_until': _lockedUntil?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _storage.write(key: _vaultKey, value: jsonEncode(data));
    } catch (e) {
      debugPrint('SecurityAuthService persist hatasi: $e');
    }
  }

  String _newSalt() {
    final rand = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rand.nextInt(256)));
  }

  /// PBKDF2 hesaplaması UI thread'ini dondurmasın diye ayrı isolate'te çalışır
  Future<String> _hashPin(String rawPin, String salt, int version) {
    return compute(_hashPinIsolate, [rawPin, salt, version]);
  }

  /// Sabit zamanlı karşılaştırma (zamanlama saldırılarına karşı)
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Yeni PIN kodu belirler ve PIN doğrulamasını aktif eder
  Future<void> setPin(String rawPin) async {
    _salt = _newSalt();
    _pinVersion = 2;
    _hashedPin = await _hashPin(rawPin, _salt!, _pinVersion);
    _isPinEnabled = true;
    _failedAttempts = 0;
    _lockedUntil = null;

    _syncNotifiers();
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

    _syncNotifiers();
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

    // PIN tanımlı değilse hiçbir giriş kabul edilmez
    if (_hashedPin == null || _salt == null) {
      return false;
    }

    final computed = await _hashPin(inputPin, _salt!, _pinVersion);
    if (_constantTimeEquals(computed, _hashedPin!)) {
      _failedAttempts = 0;
      _lockedUntil = null;
      if (_pinVersion < 2) {
        // Eski SHA-256 hash'i PBKDF2'ye sessizce yükselt
        _pinVersion = 2;
        _salt = _newSalt();
        _hashedPin = await _hashPin(inputPin, _salt!, _pinVersion);
      }
      await _persist();
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        // Her 5 hatalı denemede artan bekleme süresi: 30sn, 60sn, 120sn...
        final multiplier = 1 << ((_failedAttempts ~/ 5) - 1).clamp(0, 6);
        _lockedUntil = DateTime.now().add(Duration(seconds: 30 * multiplier));
      }
      await _persist();
      return false;
    }
  }

  /// Cihazda kayıtlı biyometri (parmak izi / yüz) var mı?
  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (e) {
      debugPrint('Biyometri kontrol hatasi: $e');
      return false;
    }
  }

  /// Biyometrik kilidi açmadan önce cihaz uyumluluğunu kontrol edip gerçek doğrulama ister.
  /// Başarılıysa null, değilse kullanıcıya gösterilecek hata mesajını döndürür.
  Future<String?> enableBiometric(BiometricAuthType type) async {
    try {
      if (!await _localAuth.isDeviceSupported() || !await _localAuth.canCheckBiometrics) {
        return 'Bu cihazda biyometrik sensör bulunamadı.';
      }
      final enrolled = await _localAuth.getAvailableBiometrics();
      if (enrolled.isEmpty) {
        return 'Cihazınızda kayıtlı parmak izi veya yüz yok. Lütfen önce telefon ayarlarından ekleyin.';
      }
      if (type == BiometricAuthType.faceId &&
          !enrolled.contains(BiometricType.face) &&
          !enrolled.contains(BiometricType.strong) &&
          !enrolled.contains(BiometricType.weak)) {
        return 'Bu cihazda yüz tanıma desteklenmiyor.';
      }
    } catch (e) {
      return 'Biyometrik donanım kontrol edilemedi: $e';
    }

    final result = await _authenticate(
      reason: type == BiometricAuthType.faceId
          ? 'Yüz tanımayı etkinleştirmek için doğrulayın'
          : 'Parmak izini etkinleştirmek için doğrulayın',
      biometricOnly: true,
    );
    if (result != null) return result;

    if (type == BiometricAuthType.faceId) {
      await setFaceIdEnabled(true);
    } else {
      await setFingerprintEnabled(true);
    }
    return null;
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

  /// Sistem biyometrik diyaloğunu açar. Başarılıysa null, değilse hata mesajı döner.
  /// [biometricOnly] false ise cihaz PIN/desen/şifresi yedek yöntem olarak kabul edilir.
  Future<String?> _authenticate({required String reason, bool biometricOnly = false}) async {
    if (isLockedOut) return 'Çok fazla hatalı deneme. Lütfen bekleyin.';
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        _failedAttempts = 0;
        _lockedUntil = null;
        return null;
      }
      return 'Biyometrik doğrulama başarısız oldu.';
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
          return 'Doğrulama iptal edildi.';
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return 'Cihazınızda kayıtlı parmak izi veya yüz yok.';
        case LocalAuthExceptionCode.noBiometricHardware:
          return 'Bu cihazda biyometrik sensör bulunamadı.';
        case LocalAuthExceptionCode.noCredentialsSet:
          return 'Cihazınızda ekran kilidi tanımlı değil.';
        default:
          return 'Biyometrik doğrulama kullanılamıyor (${e.code.name}).';
      }
    } catch (e) {
      debugPrint('Biyometrik doğrulama hatasi: $e');
      return 'Biyometrik doğrulama kullanılamıyor.';
    }
  }

  /// Yüz tanıma doğrulama köprüsü
  Future<bool> authenticateFaceId({required String reason}) async {
    return await _authenticate(reason: reason) == null;
  }

  /// Parmak izi doğrulama köprüsü
  Future<bool> authenticateFingerprint({required String reason}) async {
    return await _authenticate(reason: reason) == null;
  }

  /// Genel biyometrik çağrısı (önceki kodlarla geriye dönük uyumluluk için)
  Future<bool> authenticateBiometric({
    required String reason,
    BiometricAuthType? specificType,
  }) async {
    return await _authenticate(reason: reason) == null;
  }

  /// "Tüm verileri sıfırla" akışı için kasa kilidini tamamen temizler
  Future<void> resetAll() async {
    _isFaceIdEnabled = false;
    _isFingerprintEnabled = false;
    _isPinEnabled = false;
    _hashedPin = null;
    _salt = null;
    _failedAttempts = 0;
    _lockedUntil = null;
    _syncNotifiers();
    await _storage.delete(key: _vaultKey);
  }
}

String _hashPinIsolate(List<Object> args) {
  final pin = args[0] as String;
  final salt = args[1] as String;
  final version = args[2] as int;
  if (version < 2) {
    return sha256.convert(utf8.encode('$salt:$pin:paraiz_secure_v1')).toString();
  }
  return base64Encode(AesCipher.pbkdf2Sha256(
    pin,
    Uint8List.fromList(utf8.encode(salt)),
    iterations: SecurityAuthService._pinIterations,
  ));
}
