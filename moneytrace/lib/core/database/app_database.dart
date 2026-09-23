// lib/core/database/app_database.dart

import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  static const int schemaVersion = 3;

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
        await _runSqlAsset(db, 'assets/sql/v1_create_schema.sql');
        await _runSqlAsset(db, 'assets/sql/v1_seed_categories.sql');
        await _runSqlAsset(db, 'assets/sql/v2_statement_intelligence.sql');
        await _runSqlAsset(db, 'assets/sql/v3_manual_entry_categories.sql');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _runSqlAsset(db, 'assets/sql/v2_statement_intelligence.sql');
        }
        if (oldVersion < 3) {
          await _runSqlAsset(db, 'assets/sql/v3_manual_entry_categories.sql');
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
