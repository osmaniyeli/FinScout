// lib/core/parser/services/custom_field_mapping_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/bank_mapping_template.dart';
import '../models/parsed_models.dart';
import '../../utils/currency_normalizer.dart';

class CustomFieldMappingService {
  static final CustomFieldMappingService instance = CustomFieldMappingService._internal();

  CustomFieldMappingService._internal();

  bool _isInitialized = false;
  final List<BankMappingTemplate> _templates = [];

  List<BankMappingTemplate> get templates => List.unmodifiable(_templates);

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/custom_bank_templates.json');
  }

  /// Varsayılan hazır banka dekont şablonları
  List<BankMappingTemplate> get _defaultTemplates => [
    const BankMappingTemplate(
      id: 'template_fibabanka_fast',
      bankName: 'Fibabanka',
      templateName: 'Fibabanka FAST / EFT Dekontu',
      documentType: 'RECEIPT',
      amountField: 'İşlem Tutarı:',
      dateField: 'İşlem Tarihi:',
      descriptionField: 'Açıklama:',
      recipientField: 'Alıcı Adı:',
      balanceField: 'Kalan Bakiye:',
      defaultTransactionType: 'EXPENSE',
      defaultCategory: 'transfer',
      matchKeywords: ['FİBABANKA', 'FIBABANKA', 'FAST', 'DEKONT'],
    ),
    const BankMappingTemplate(
      id: 'template_kuveytturk_dekont',
      bankName: 'Kuveyt Türk',
      templateName: 'Kuveyt Türk Para Transferi Dekontu',
      documentType: 'RECEIPT',
      amountField: 'Tutar:',
      dateField: 'İşlem Tarihi:',
      descriptionField: 'Açıklama:',
      recipientField: 'Alıcı Ünvanı / Adı:',
      balanceField: 'Kalan Bakiye:',
      defaultTransactionType: 'EXPENSE',
      defaultCategory: 'transfer',
      matchKeywords: ['KUVEYT TÜRK', 'KUVEYTTURK', 'DEKONT'],
    ),
    const BankMappingTemplate(
      id: 'template_papara_transfer',
      bankName: 'Papara',
      templateName: 'Papara Transfer Dekontu',
      documentType: 'RECEIPT',
      amountField: 'İşlem Tutarı:',
      dateField: 'Tarih:',
      descriptionField: 'Açıklama:',
      recipientField: 'Alıcı:',
      defaultTransactionType: 'EXPENSE',
      defaultCategory: 'transfer',
      matchKeywords: ['PAPARA', 'İŞLEM DEKONTU'],
    ),
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        _templates.clear();
        for (final item in list) {
          _templates.add(BankMappingTemplate.fromJson(item as Map<String, dynamic>));
        }
      } else {
        _templates.clear();
        _templates.addAll(_defaultTemplates);
        await _persist();
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('CustomFieldMappingService init hatasi: $e');
      _templates.clear();
      _templates.addAll(_defaultTemplates);
      _isInitialized = true;
    }
  }

  Future<void> _persist() async {
    try {
      final file = await _getStorageFile();
      final data = _templates.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('CustomFieldMappingService persist hatasi: $e');
    }
  }

  /// Yeni şablon kaydeder veya günceller
  Future<void> saveTemplate(BankMappingTemplate template) async {
    await initialize();
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _templates[index] = template;
    } else {
      _templates.add(template);
    }
    await _persist();
  }

  /// Şablonu siler
  Future<void> deleteTemplate(String templateId) async {
    await initialize();
    _templates.removeWhere((t) => t.id == templateId);
    await _persist();
  }

  /// Belge metnine uyan en uygun şablonu arar
  BankMappingTemplate? findMatchingTemplate(String rawText) {
    final upper = rawText.toUpperCase();
    for (final template in _templates) {
      if (template.matchKeywords.isNotEmpty) {
        final matchCount = template.matchKeywords.where((kw) => upper.contains(kw.toUpperCase())).length;
        if (matchCount >= 2 || (template.matchKeywords.length == 1 && matchCount == 1)) {
          return template;
        }
      }
    }
    return null;
  }

  /// Ham dekont/ekstre metninden otomatik olarak etiketleri (Key-Value çiftlerini) ayıklar.
  /// Kullanıcı bu etiketler arasından Tutar, Tarih, Açıklama ve Alıcı alanlarını kolayca seçebilir.
  Map<String, String> extractCandidateFields(String rawText) {
    final Map<String, String> candidates = {};
    final lines = rawText.split(RegExp(r'[\r\n]+'));

    // 1. Standart İki Noktalı Satır Eşleşmesi (Örn: "İşlem Tutarı : 1.450,00 TL")
    final colonRegex = RegExp(r'^([A-Za-zÇĞİÖŞÜçğıöşü0-9\s\.\-_/]{2,35})\s*[:=]\s*(.+)$');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final match = colonRegex.firstMatch(trimmed);
      if (match != null) {
        final key = '${match.group(1)!.trim()}:';
        final val = match.group(2)!.trim();
        if (val.isNotEmpty && !candidates.containsKey(key)) {
          candidates[key] = val;
        }
      }
    }

    // 2. Tutar ve Sayı İçeren Satırları da Yedek Olarak Tara
    final moneyRegex = RegExp(r'([0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2}\s*(?:TL|₺|EUR|USD)?)');
    for (final line in lines) {
      final trimmed = line.trim();
      final match = moneyRegex.firstMatch(trimmed);
      if (match != null) {
        final matchedVal = match.group(0)!;
        final prefix = trimmed.substring(0, match.start).trim();
        if (prefix.isNotEmpty && prefix.length <= 35) {
          final key = prefix.endsWith(':') ? prefix : '$prefix:';
          if (!candidates.containsKey(key)) {
            candidates[key] = matchedVal;
          }
        }
      }
    }

    return candidates;
  }

  /// Şablon kurallarını ham metne uygulayıp deterministik ParsedRecord üretir.
  /// Körü körüne tahmin yerine doğrudan kullanıcının tanımladığı alan eşleşmesini kullanır.
  ParsedRecord? applyTemplate(String rawText, BankMappingTemplate template) {
    final lines = rawText.split(RegExp(r'[\r\n]+'));

    String? rawAmountStr;
    String? rawDateStr;
    String? rawDescStr;
    String? rawRecipientStr;

    for (final line in lines) {
      final trimmed = line.trim();

      // 1. Tutar Alanı Arama
      if (rawAmountStr == null && trimmed.toLowerCase().contains(template.amountField.toLowerCase())) {
        final cleanAfterKey = _extractValueAfterLabel(trimmed, template.amountField);
        if (cleanAfterKey.isNotEmpty) {
          rawAmountStr = cleanAfterKey;
        }
      }

      // 2. Tarih Alanı Arama
      if (template.dateField != null && rawDateStr == null && trimmed.toLowerCase().contains(template.dateField!.toLowerCase())) {
        final cleanAfterKey = _extractValueAfterLabel(trimmed, template.dateField!);
        if (cleanAfterKey.isNotEmpty) {
          rawDateStr = cleanAfterKey;
        }
      }

      // 3. Açıklama Alanı Arama
      if (template.descriptionField != null && rawDescStr == null && trimmed.toLowerCase().contains(template.descriptionField!.toLowerCase())) {
        final cleanAfterKey = _extractValueAfterLabel(trimmed, template.descriptionField!);
        if (cleanAfterKey.isNotEmpty) {
          rawDescStr = cleanAfterKey;
        }
      }

      // 4. Alıcı / Karşı Taraf Arama
      if (template.recipientField != null && rawRecipientStr == null && trimmed.toLowerCase().contains(template.recipientField!.toLowerCase())) {
        final cleanAfterKey = _extractValueAfterLabel(trimmed, template.recipientField!);
        if (cleanAfterKey.isNotEmpty) {
          rawRecipientStr = cleanAfterKey;
        }
      }
    }

    if (rawAmountStr == null) {
      return null;
    }

    // Tutar Dönüşümü (Kuruş bazlı)
    final amountCents = CurrencyNormalizer.toMinorUnits(rawAmountStr);
    if (amountCents <= 0) {
      return null;
    }

    // Tarih Ayrıştırma
    DateTime txDate = DateTime.now();
    if (rawDateStr != null) {
      final dateMatch = RegExp(r'(\d{1,2})[\./\-](\d{1,2})[\./\-](\d{2,4})').firstMatch(rawDateStr);
      if (dateMatch != null) {
        final day = int.tryParse(dateMatch.group(1)!) ?? 1;
        final month = int.tryParse(dateMatch.group(2)!) ?? 1;
        var year = int.tryParse(dateMatch.group(3)!) ?? DateTime.now().year;
        if (year < 100) year += 2000;
        txDate = DateTime(year, month, day);
      }
    }

    // Açıklama & Karşı Taraf Birleştirme
    final descriptionParts = <String>[];
    if (rawRecipientStr != null && rawRecipientStr.isNotEmpty) {
      descriptionParts.add(rawRecipientStr);
    }
    if (rawDescStr != null && rawDescStr.isNotEmpty) {
      descriptionParts.add(rawDescStr);
    }
    final finalMerchant = descriptionParts.isNotEmpty
        ? descriptionParts.join(' - ')
        : '${template.bankName} Dekont İşlemi';

    final isIncome = template.defaultTransactionType.toUpperCase() == 'INCOME';
    return ParsedRecord(
      cardOrAccountMask: '****',
      cardHolder: rawRecipientStr,
      date: txDate,
      type: isIncome ? ParsedTransactionType.credit : ParsedTransactionType.debit,
      rawDescription: finalMerchant,
      cleanMerchant: finalMerchant,
      categoryId: template.defaultCategory,
      billingAmountCents: amountCents,
      billingCurrency: 'TRY',
    );
  }

  String _extractValueAfterLabel(String line, String label) {
    final idx = line.toLowerCase().indexOf(label.toLowerCase());
    if (idx < 0) return '';
    var after = line.substring(idx + label.length).trim();
    if (after.startsWith(':') || after.startsWith('=')) {
      after = after.substring(1).trim();
    }
    return after;
  }
}
