// lib/core/database/database_migrator.dart
import 'package:sqflite/sqflite.dart';

class DatabaseMigrator {
  static const int targetVersion = 2;

  static Future<void> setupAndMigrate(Database db) async {
    // 1. Foreign key desteğini aktif et
    await db.execute('PRAGMA foreign_keys = ON;');

    // 2. Mevcut veritabanı versiyonunu oku
    final result = await db.rawQuery('PRAGMA user_version;');
    int currentVersion = result.first.values.first as int;

    if (currentVersion == 0) {
      // İlk kurulum: V1 şemasını ve tohumları yükle
      await _applyMigrationV1(db);
      await db.execute('PRAGMA user_version = 1;');
      currentVersion = 1;
    }

    // 3. Sıralı Migration zinciri
    if (currentVersion < 2) {
      await _applyMigrationV2(db);
      await db.execute('PRAGMA user_version = 2;');
      currentVersion = 2;
    }
  }

  static Future<void> _applyMigrationV1(Database db) async {
    // Yukarıdaki V1 DDL script'ini transaction içinde çalıştırır
    await db.transaction((txn) async {
      // DDL tabloları oluşturulur
      // await txn.execute(sqlV1Statements);
    });
  }

  static Future<void> _applyMigrationV2(Database db) async {
    // Versiyon 2: BES getiri takibi ve döviz spread (makas) sütunları ekleme
    await db.transaction((txn) async {
      await txn.execute('''
        ALTER TABLE assets ADD COLUMN yield_rate REAL DEFAULT 0.0;
      ''');
      await txn.execute('''
        ALTER TABLE transactions ADD COLUMN fx_bank_markup_cents INTEGER DEFAULT 0;
      ''');
    });
  }
}