// test/backup_service_test.dart
//
// Otomatik, hesaba bağlı, uçtan uca şifreli yedekleme (BackupService) için üç şey doğrulanır:
//  1) Şifreleme round-trip: DataExportService + AesCipher (BackupService'in AYNEN yeniden
//     kullandığı, önceden var olan katman) uydurma bir anahtarla encrypt→decrypt sonrası
//     aynı JSON'u veriyor mu.
//  2) restoreIfEmpty() koruması: telefonda finansal veri VARKEN hiçbir ağ çağrısı yapmadan
//     (fetchKeyOverride hiç tetiklenmeden) false dönüyor mu — var olan veri asla ezilmiyor.
//  3) Debounce: DataChanges.revision art arda birden çok kez tetiklendiğinde, debounce
//     penceresi içinde kalan tetiklemeler TEK bir backupNow çalıştırmasına iniyor mu.
//
// Gerçek Supabase/ağ isteği ATILMAZ: forTesting() ile enjekte edilen sahte/stub bağımlılıklar
// kullanılır (fetchKeyOverride, onBackupRun). DB gerektiren test (2) flutter_test VM'de sqflite'ı
// FFI ile, path_provider'ı sahte bir geçici klasörle çalıştırır (bkz. own_transfer_reconciliation_test.dart).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:moneytrace/core/database/app_database.dart';
import 'package:moneytrace/core/security/aes_cipher.dart';
import 'package:moneytrace/core/services/backup_service.dart';
import 'package:moneytrace/core/services/data_changes.dart';
import 'package:moneytrace/core/services/data_export_service.dart';
import 'package:moneytrace/core/services/user_profile_service.dart';

/// path_provider'ı gerçek platform kanalı olmadan, her testte ayrı bir geçici klasöre yönlendirir.
class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Şifreleme round-trip (AesCipher + DataExportService, AYNEN yeniden kullanılan katman)', () {
    test('uydurma bir keyBase64 ile encrypt → decrypt aynı JSON verisini geri verir', () {
      final json = DataExportService.instance.createFullVaultBackupJson(
        accounts: [
          {'id': 'acc_1', 'institution_name': 'Yapı Kredi', 'account_type': 'CHECKING'}
        ],
        statements: [
          {'id': 'st_1', 'account_id': 'acc_1'}
        ],
        transactions: [
          {'id': 'tx_1', 'account_id': 'acc_1', 'billing_amount_cents': 12345}
        ],
        installments: const [],
        taxes: const [],
        extras: {
          'goals': [
            {'id': 'g_1', 'title': 'Tatil'}
          ],
        },
      );

      // Gerçek bir backup-key yanıtı gibi: yüksek entropili, base64 bir dize (uydurma).
      const fakeKeyBase64 = 'q3F7pQvC9m2Zk0Xr8sYd1tLg6uHn4bWe5cVo7yTiP2A=';

      final envelope = AesCipher.encryptVaultPayload(plainText: json, password: fakeKeyBase64);
      expect(envelope, startsWith('PARAIZ-SEC-VAULT-V2:'));

      // BackupService.restoreIfEmpty tam olarak bu yolu kullanıyor: validateAndParseBackup
      // zarfı algılayıp AesCipher.decryptVaultPayload'ı kendi içinde çağırıyor.
      final parsed = DataExportService.instance
          .validateAndParseBackup(envelope, password: fakeKeyBase64);

      expect(parsed['accounts'], hasLength(1));
      expect(parsed['accounts'][0]['id'], 'acc_1');
      expect(parsed['transactions'][0]['billing_amount_cents'], 12345);
      expect(parsed['goals'], hasLength(1));
      expect(parsed['goals'][0]['title'], 'Tatil');
    });

    test('yanlış anahtarla çözme HMAC bütünlük hatası fırlatır (parola/anahtar hatalıysa sessizce yanlış veri dönmez)', () {
      final json = DataExportService.instance.createFullVaultBackupJson(
        accounts: const [],
        statements: const [],
        transactions: const [],
        installments: const [],
        taxes: const [],
      );
      final envelope =
          AesCipher.encryptVaultPayload(plainText: json, password: 'dogru-anahtar-AAAA');

      expect(
        () => AesCipher.decryptVaultPayload(vaultString: envelope, password: 'yanlis-anahtar-BBBB'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BackupService.restoreIfEmpty() — var olan yerel veriyi asla ezmez', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('finscout_backup_test_');
      PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Windows'ta dosya tanıtıcısı hemen serbest kalmayabilir; testi bozmasın.
      }
    });

    test('telefonda finansal veri VARKEN restoreIfEmpty false döner ve ağ katmanına (fetchKey) hiç inmez', () async {
      // Yerelde bir hesap kaydı olsun: hasLocalFinancialData() true dönmeli.
      final db = await AppDatabase.instance.database;
      await db.insert('accounts', {
        'id': 'acc_existing',
        'institution_name': 'Yapı Kredi',
        'account_type': 'CHECKING',
        'account_name': 'Mevcut Hesap',
        'card_mask': '',
        'currency_code': 'TRY',
        'created_at': 0,
      });
      expect(await UserProfileService.instance.hasLocalFinancialData(), isTrue);

      var fetchKeyCalled = false;
      final service = BackupService.forTesting(
        debounce: const Duration(milliseconds: 30),
        fetchKeyOverride: () async {
          fetchKeyCalled = true;
          return 'her-zaman-donen-anahtar';
        },
      );

      final restored = await service.restoreIfEmpty();

      expect(restored, isFalse);
      expect(fetchKeyCalled, isFalse,
          reason: 'Yerelde veri varken sunucudaki yedeğe (anahtar dahil) hiç bakılmamalı');
    });
  });

  group('BackupService debounce — art arda DataChanges tetiklemeleri tek çalıştırmaya iner', () {
    test('debounce penceresi içindeki çoklu DataChanges.notify() çağrısı tek backupNow çalıştırır', () async {
      var runCount = 0;
      final service = BackupService.forTesting(
        debounce: const Duration(milliseconds: 40),
        // Gerçek ağ/oturum yolu hiç kullanılmasın: her çalıştırmada sadece sayaç artır.
        fetchKeyOverride: () async => null,
        onBackupRun: () => runCount++,
      );

      await service.initialize();
      addTearDown(service.dispose);

      // Debounce penceresi (40ms) içinde art arda 5 tetikleme: hepsi tek bir çalıştırmaya inmeli.
      for (var i = 0; i < 5; i++) {
        DataChanges.notify();
        await Future.delayed(const Duration(milliseconds: 5));
      }

      // Son tetiklemeden sonra debounce süresinin dolmasını bekle.
      await Future.delayed(const Duration(milliseconds: 120));

      expect(runCount, 1,
          reason: 'Debounce penceresi içindeki art arda tetiklemeler tek bir yüklemeye inmeli');
    });

    test('debounce penceresi dışında kalan tetiklemeler ayrı ayrı çalışır', () async {
      var runCount = 0;
      final service = BackupService.forTesting(
        debounce: const Duration(milliseconds: 30),
        fetchKeyOverride: () async => null,
        onBackupRun: () => runCount++,
      );

      await service.initialize();
      addTearDown(service.dispose);

      DataChanges.notify();
      await Future.delayed(const Duration(milliseconds: 80)); // ilk debounce'un dolmasını bekle

      DataChanges.notify();
      await Future.delayed(const Duration(milliseconds: 80)); // ikinci debounce'un dolmasını bekle

      expect(runCount, 2,
          reason: 'Debounce penceresi dışında kalan tetiklemeler ayrı yüklemeler olarak sayılmalı');
    });
  });
}
