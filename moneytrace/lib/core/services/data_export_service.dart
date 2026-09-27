// lib/core/services/data_export_service.dart

import 'dart:convert';
import '../database/repositories/transaction_repository.dart';
import '../security/aes_cipher.dart';

class DataExportService {
  static final DataExportService instance = DataExportService._internal();
  DataExportService._internal();

  /// Tüm SQLite Tablolarını Standart Güvenli JSON Zarfına Dönüştürür
  String createFullVaultBackupJson({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> statements,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> installments,
    required List<Map<String, dynamic>> taxes,
    Map<String, List<Map<String, dynamic>>> extras = const {},
  }) {
    final payload = {
      'app': 'FinScout',
      'version': '1.0.0',
      'vault_format': 'zero_knowledge_v1',
      'created_at': DateTime.now().toIso8601String(),
      'metrics': {
        'total_accounts': accounts.length,
        'total_statements': statements.length,
        'total_transactions': transactions.length,
        'total_installments': installments.length,
        'total_taxes': taxes.length,
      },
      'data': {
        'accounts': accounts,
        'statements': statements,
        'transactions': transactions,
        'installments': installments,
        'tax_deductions': taxes,
        ...extras,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parola Korumalı AES-256-CBC Şifreli Kasa Yedeği (.vault) Üretir
  String createEncryptedVaultBackup({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> statements,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> installments,
    required List<Map<String, dynamic>> taxes,
    Map<String, List<Map<String, dynamic>>> extras = const {},
    required String password,
  }) {
    if (password.length < 6) {
      throw ArgumentError('Yedekleme parolası en az 6 karakter olmalıdır.');
    }
    final rawJson = createFullVaultBackupJson(
      accounts: accounts,
      statements: statements,
      transactions: transactions,
      installments: installments,
      taxes: taxes,
      extras: extras,
    );
    return AesCipher.encryptVaultPayload(plainText: rawJson, password: password);
  }

  /// Yedek Dosyasını Doğrular ve Ayrıştırır (Düz Metin JSON veya AES-256 Şifreli Kasa)
  Map<String, dynamic> validateAndParseBackup(String rawContent, {String? password}) {
    String resolvedJson = rawContent.trim();

    // 1. Şifreli Kasa Formatı Kontrolü
    if (resolvedJson.startsWith('PARAIZ-SEC-VAULT-V2:')) {
      if (password == null || password.isEmpty) {
        throw const FormatException('VAULT_PASSWORD_REQUIRED: Bu yedek dosyası AES-256 ile şifrelenmiştir. Lütfen parolanızı giriniz.');
      }
      resolvedJson = AesCipher.decryptVaultPayload(vaultString: resolvedJson, password: password);
    }

    final dynamic decoded = jsonDecode(resolvedJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geçersiz yedek dosyası: JSON formatı doğrulanamadı.');
    }

    // 'ParaIz (MoneyTrace)': marka birleştirmesinden önce alınmış yedekler
    const knownApps = {'FinScout', 'ParaIz (MoneyTrace)'};
    if (!knownApps.contains(decoded['app']) || !decoded.containsKey('data')) {
      throw const FormatException('Bu dosya geçerli bir FinScout yedekleme arşivi değildir.');
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Yedek verisi bozuk veya eksik.');
    }

    return {
      'accounts': (data['accounts'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'statements': (data['statements'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'transactions': (data['transactions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'installments': (data['installments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      'tax_deductions': (data['tax_deductions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      // Eski yedeklerde bulunmayabilir; yoksa geri yüklemede mevcut kayıtlara dokunulmaz
      for (final t in TransactionRepositoryBackup.extraTables)
        if (data[t] is List) t: (data[t] as List<dynamic>).cast<Map<String, dynamic>>(),
    };
  }
}
