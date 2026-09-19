// lib/core/database/app_database.dart

import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

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
      version: 1,
      onCreate: (db, version) async {
        // 1. DDL Şemasını yükle ve çalıştır
        final schemaSql = await rootBundle.loadString('assets/sql/v1_create_schema.sql');
        final statements = schemaSql.split(';');
        for (var statement in statements) {
          final trimmed = statement.trim();
          if (trimmed.isNotEmpty) {
            await db.execute(trimmed);
          }
        }

        // 2. Kategori tohum verilerini yükle
        final seedSql = await rootBundle.loadString('assets/sql/v1_seed_categories.sql');
        final seedStatements = seedSql.split(';');
        for (var statement in seedStatements) {
          final trimmed = statement.trim();
          if (trimmed.isNotEmpty) {
            await db.execute(trimmed);
          }
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
