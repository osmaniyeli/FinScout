import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/database/app_database.dart';

/// AppDatabase._runSqlAsset ile aynı bölme kuralı: '--' yorum satırları atılır, ';' ile bölünür.
List<String> _statements(String path) {
  final sql = File(path).readAsStringSync();
  return sql
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('--'))
      .join('\n')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

void main() {
  group('AppDatabase göçleri', () {
    test('şema sürümü 5 ve her sürümün göç dosyası var', () {
      expect(AppDatabase.schemaVersion, 5);
      for (var v = 1; v <= AppDatabase.schemaVersion; v++) {
        final scripts = AppDatabase.migrationScripts[v];
        expect(scripts, isNotNull, reason: 'v$v göçü tanımlı değil');
        for (final s in scripts!) {
          expect(File(s).existsSync(), isTrue, reason: '$s bulunamadı');
          expect(s.startsWith('assets/sql/'), isTrue, reason: 'pubspec yalnız assets/sql/ klasörünü paketler');
        }
      }
    });

    test('sıfırdan kurulum v1..v5 dosyalarını eski sırayla çalıştırır', () {
      expect(AppDatabase.createScripts(), [
        'assets/sql/v1_create_schema.sql',
        'assets/sql/v1_seed_categories.sql',
        'assets/sql/v2_statement_intelligence.sql',
        'assets/sql/v3_manual_entry_categories.sql',
        'assets/sql/v4_payslip_wage.sql',
        'assets/sql/v5_indexes.sql',
      ]);
    });

    test('yükseltme yalnız eski sürümden sonraki dosyaları çalıştırır', () {
      expect(AppDatabase.upgradeScripts(4), ['assets/sql/v5_indexes.sql']);
      expect(AppDatabase.upgradeScripts(3), ['assets/sql/v4_payslip_wage.sql', 'assets/sql/v5_indexes.sql']);
      expect(AppDatabase.upgradeScripts(1), [
        'assets/sql/v2_statement_intelligence.sql',
        'assets/sql/v3_manual_entry_categories.sql',
        'assets/sql/v4_payslip_wage.sql',
        'assets/sql/v5_indexes.sql',
      ]);
      expect(AppDatabase.upgradeScripts(5), isEmpty);
    });

    test('v5 yalnız tekrar çalıştırılabilir indeks ekler (veri/şema değiştirmez)', () {
      final statements = _statements('assets/sql/v5_indexes.sql');
      expect(statements, isNotEmpty);
      for (final s in statements) {
        expect(s.toUpperCase().startsWith('CREATE INDEX IF NOT EXISTS'), isTrue, reason: s);
      }
      // Ölçümle gerekçelenen indeksler (bkz. dosya başındaki not)
      final joined = statements.join('\n');
      expect(joined, contains('idx_installments_transaction ON installments(transaction_id)'));
      expect(joined, contains('idx_transactions_statement_kind ON transactions(statement_id, tx_kind)'));
      expect(joined, contains('idx_statements_account_date ON statements(account_id, statement_date)'));
    });

    test('v5 indeks adları önceki göçlerdekilerle çakışmaz', () {
      final nameRe = RegExp(r'INDEX IF NOT EXISTS (\w+)', caseSensitive: false);
      final earlier = <String>{};
      for (final f in AppDatabase.upgradeScripts(0).where((f) => !f.contains('v5_'))) {
        earlier.addAll(nameRe.allMatches(File(f).readAsStringSync()).map((m) => m.group(1)!));
      }
      final v5 = nameRe
          .allMatches(File('assets/sql/v5_indexes.sql').readAsStringSync())
          .map((m) => m.group(1)!)
          .toList();
      expect(v5.toSet().length, v5.length);
      expect(v5.toSet().intersection(earlier), isEmpty);
    });
  });
}
