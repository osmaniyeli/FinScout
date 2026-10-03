// Denetim 2/5 (güvenlik): kripto, PII maskeleme ve yedek sahiplik koruması.
// Bkz. docs/audit/security-audit.md (SEC-xx kimlikleri test adlarında).

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/security/aes_cipher.dart';
import 'package:moneytrace/core/security/pdf_malware_scanner.dart';
import 'package:moneytrace/core/security/pii_redactor.dart';
import 'package:moneytrace/core/security/security_guard.dart';
import 'package:moneytrace/core/services/backup_service.dart';

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
Uint8List _unhex(String s) => Uint8List.fromList(
    [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);

/// Zarfı açıp bir alanını değiştirip yeniden paketler (saldırganın sunucudaki blob'u değiştirmesi).
String _mutateEnvelope(String vault, void Function(Map<String, dynamic>) edit) {
  const prefix = 'PARAIZ-SEC-VAULT-V2:';
  final env = jsonDecode(utf8.decode(base64Decode(vault.substring(prefix.length))))
      as Map<String, dynamic>;
  edit(env);
  return '$prefix${base64Encode(utf8.encode(jsonEncode(env)))}';
}

void main() {
  group('SEC-12 elle yazılmış AES/PBKDF2 standart test vektörleri', () {
    test('AES-256 FIPS-197 Ek C.3 vektörü (CBC, IV=0 → ilk blok = ECB)', () {
      final key = _unhex('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
      final pt = _unhex('00112233445566778899aabbccddeeff');
      final ct = AesCipher.encryptCbc(pt, key, Uint8List(16));
      expect(_hex(ct.sublist(0, 16)), '8ea2b7ca516745bfeafc49904b496089');
      expect(AesCipher.decryptCbc(ct, key, Uint8List(16)), pt);
    });

    test('PBKDF2-HMAC-SHA256 (password/salt, c=1 ve c=2, dkLen=32) bilinen çıktılar', () {
      final salt = Uint8List.fromList(utf8.encode('salt'));
      expect(_hex(AesCipher.pbkdf2Sha256('password', salt, iterations: 1)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(_hex(AesCipher.pbkdf2Sha256('password', salt, iterations: 2)),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    });
  });

  group('SEC-12 yedek zarfı bütünlüğü', () {
    const key = 'dGVzdC1rZXktMzItYnl0ZXMtYmFzZTY0LWVuY29kZWQ=';
    final vault = AesCipher.encryptVaultPayload(plainText: '{"a":1}', password: key);

    test('doğru anahtarla açılır', () {
      expect(AesCipher.decryptVaultPayload(vaultString: vault, password: key), '{"a":1}');
    });

    test('şifreli metnin tek baytı değişirse MAC reddeder', () {
      final tampered = _mutateEnvelope(vault, (e) {
        final ct = base64Decode(e['ct'] as String);
        ct[0] ^= 0x01;
        e['ct'] = base64Encode(ct);
      });
      expect(() => AesCipher.decryptVaultPayload(vaultString: tampered, password: key),
          throwsFormatException);
    });

    test('zarftaki dev "iter" değeri reddedilir (geri yüklemeyi kilitleyen DoS yok)', () {
      final hostile = _mutateEnvelope(vault, (e) => e['iter'] = 2000000000);
      final sw = Stopwatch()..start();
      expect(() => AesCipher.decryptVaultPayload(vaultString: hostile, password: key),
          throwsFormatException);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('sabit zamanlı karşılaştırma doğru sonuç verir', () {
      expect(AesCipher.constantTimeEquals('abcd', 'abcd'), isTrue);
      expect(AesCipher.constantTimeEquals('abcd', 'abce'), isFalse);
      expect(AesCipher.constantTimeEquals('abc', 'abcd'), isFalse);
    });
  });

  group('SEC-01 yedek: telefondaki veri başka hesaba aitse yüklenmez', () {
    test('sahip farklı → yükleme YOK', () {
      expect(BackupService.mayUploadFor(localOwnerId: 'user-A', sessionUserId: 'user-B'), isFalse);
    });
    test('sahip aynı → yükleme var', () {
      expect(BackupService.mayUploadFor(localOwnerId: 'user-B', sessionUserId: 'user-B'), isTrue);
    });
    test('sahip bilinmiyor (eski kurulum) → yükleme var (mevcut davranış korunur)', () {
      expect(BackupService.mayUploadFor(localOwnerId: null, sessionUserId: 'user-B'), isTrue);
      expect(BackupService.mayUploadFor(localOwnerId: '', sessionUserId: 'user-B'), isTrue);
    });
  });

  group('SEC-15 PiiRedactor gerçek PII kalıplarını maskeler', () {
    test('IBAN (boşluklu ve bitişik)', () {
      expect(PiiRedactor.redact('TR33 0006 1005 1978 6457 8413 26'), isNot(contains('1978')));
      expect(PiiRedactor.redact('TR330006100519786457841326'), isNot(contains('19786457')));
    });
    test('16 haneli kart numarası: ilk 6 + son 4 dışında maskelenir', () {
      final out = PiiRedactor.redact('KART 4462 1234 5678 8281');
      expect(out, contains('8281'));
      expect(out, isNot(contains('5678')));
    });
    test('TCKN ve cep telefonu', () {
      expect(PiiRedactor.redact('TCKN 12345678901'), isNot(contains('45678')));
      expect(PiiRedactor.redact('TEL 0532 123 45 67'), isNot(contains('123 45')));
    });
    test('tutar ve kısa sayılar bozulmaz', () {
      expect(PiiRedactor.redact('POS 123456 TUTAR 1.234,56'), 'POS 123456 TUTAR 1.234,56');
    });
  });

  group('SEC-16 PDF tarayıcı açık imzaları yakalar', () {
    test('/JavaScript ve /OpenAction içeren PDF reddedilir', () {
      final pdf = Uint8List.fromList(
          latin1.encode('%PDF-1.7\n1 0 obj << /OpenAction 2 0 R /JavaScript 3 0 R >> endobj'));
      expect(PdfMalwareScanner.scanBytes(pdf).isSafe, isFalse);
    });
    test('PDF olmayan dosya reddedilir; 15 MB üstü reddedilir', () {
      expect(SecurityGuard.instance.validatePdfFile(bytes: Uint8List.fromList([1, 2, 3, 4, 5, 6])),
          isFalse);
      final big = Uint8List(15728641)..setAll(0, latin1.encode('%PDF-'));
      expect(SecurityGuard.instance.validatePdfFile(bytes: big), isFalse);
    });
  });

  test('SEC-06 isDatabaseEncrypted dürüst: SQLite şifresiz', () {
    expect(SecurityGuard.instance.isDatabaseEncrypted(), isFalse);
  });
}
