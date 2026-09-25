// lib/core/database/app_database.dart

import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  static const int schemaVersion = 5;

  /// Şema sürümü → o sürüme geçişte çalışan SQL dosyası. Yeni kurulum hepsini sırayla çalıştırır
  /// (v1 iki dosyadan oluşur), yükseltme yalnız eski sürümden sonrakileri.
  static const Map<int, List<String>> migrationScripts = {
    1: ['assets/sql/v1_create_schema.sql', 'assets/sql/v1_seed_categories.sql'],
    2: ['assets/sql/v2_statement_intelligence.sql'],
    3: ['assets/sql/v3_manual_entry_categories.sql'],
    4: ['assets/sql/v4_payslip_wage.sql'],
    5: ['assets/sql/v5_indexes.sql'],
  };

  /// Sıfırdan kurulumda çalışacak dosyalar.
  static List<String> createScripts() => upgradeScripts(0);

  /// [oldVersion]'dan [schemaVersion]'a yükseltirken sırayla çalışacak dosyalar.
  static List<String> upgradeScripts(int oldVersion) => [
        for (var v = oldVersion + 1; v <= schemaVersion; v++) ...?migrationScripts[v],
      ];

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'paraiz_vault.db');

    return await openDatabase(
      dbPath,
      version: schemaVersion,
      onCreate: (db, version) async {
        for (final script in createScripts()) {
          await _runSqlAsset(db, script);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (final script in upgradeScripts(oldVersion)) {
          await _runSqlAsset(db, script);
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// SQL dosyasını ';' ile bölüp sırayla çalıştırır ('--' yorum satırları atlanır).
  static Future<void> _runSqlAsset(Database db, String assetPath) async {
    final sql = await rootBundle.loadString(assetPath);
    final withoutComments = sql
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n');
    for (final statement in withoutComments.split(';')) {
      final trimmed = statement.trim();
      if (trimmed.isNotEmpty) {
        await db.execute(trimmed);
      }
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
