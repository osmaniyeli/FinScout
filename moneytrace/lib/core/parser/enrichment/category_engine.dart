// lib/core/parser/enrichment/category_engine.dart

import 'dart:convert';

import '../models/parsed_models.dart';
import '../services/merchant_sanitizer.dart';
import '../util/tr_statement_text.dart';

class CategoryMatch {
  final String categoryId;
  final String? sector;
  final String? brand;
  final CategorySource source;

  const CategoryMatch(this.categoryId, {this.sector, this.brand, required this.source});
}

enum CategorySource { userRule, transactionKind, dictionary, builtInRule, bankSector, fallback }

/// Kategori + sektör çözümleyici. Öncelik sırası (ilk eşleşen kazanır):
/// 1. Kullanıcının kendi düzeltmelerinden öğrenilen kurallar (merchant_rules tablosu)
/// 2. İşlem türü (kart ödemesi, faiz, vergi, havale, maaş... kategorisi türden bellidir)
/// 3. Üye işyeri sözlüğü (assets/dictionaries/merchant_sectors_tr.json) — en uzun kalıp kazanır
/// 4. Yerleşik anahtar kelime kuralları (MerchantSanitizer)
/// 5. Bankanın kendi sektör etiketi (ör. Garanti "Eczane", "Ulaşım")
class CategoryEngine {
  CategoryEngine._();
  static final CategoryEngine instance = CategoryEngine._();

  final List<_DictEntry> _dictionary = [];
  bool get hasDictionary => _dictionary.isNotEmpty;

  /// Sözlük JSON'unu yükler (uygulamada rootBundle, testte dosyadan). Bozuk veri sessizce yok sayılır.
  void loadDictionary(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final entries = (data['entries'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _dictionary
        ..clear()
        ..addAll(entries
            .where((e) => (e['pattern'] as String?)?.trim().isNotEmpty == true && e['category'] != null)
            .map((e) => _DictEntry(
                  TrStatementText.fold(e['pattern'] as String),
                  e['category'] as String,
                  e['sector'] as String?,
                  e['brand'] as String?,
                )))
        // Uzun kalıp önce: "SHELL" yerine "SHELL CAFE" gibi daha özgül eşleşme kazanır
        ..sort((a, b) => b.pattern.length.compareTo(a.pattern.length));
    } catch (_) {
      _dictionary.clear();
    }
  }

  static const Map<TransactionKind, String> _kindCategories = {
    TransactionKind.cardPayment: 'cat_card_payment',
    TransactionKind.interestFee: 'cat_fees',
    TransactionKind.tax: 'cat_tax',
    TransactionKind.cashAdvance: 'cat_cash',
    TransactionKind.ownTransfer: 'cat_transfer',
    TransactionKind.salary: 'cat_salary',
    TransactionKind.loanPayment: 'cat_loan',
  };

  static const Map<String, String> _bankSectors = {
    'ECZANE': 'cat_health', 'SAGLIK': 'cat_health', 'OPTIK': 'cat_health', 'ULASIM': 'cat_transit',
    'AKARYAKIT': 'cat_fuel', 'MARKET': 'cat_market', 'GIDA': 'cat_market', 'RESTORAN': 'cat_dining',
    'YEME': 'cat_dining', 'GIYIM': 'cat_clothing', 'TEKSTIL': 'cat_clothing', 'ELEKTRONIK': 'cat_electronics',
    'GSM': 'cat_utilities', 'TELEKOM': 'cat_utilities', 'EGITIM': 'cat_education', 'KIRTASIYE': 'cat_education',
    'SEYAHAT': 'cat_travel', 'TURIZM': 'cat_travel', 'KONAKLAMA': 'cat_travel', 'SIGORTA': 'cat_insurance',
    'MOBILYA': 'cat_home', 'YAPI': 'cat_home', 'KOZMETIK': 'cat_personal_care', 'KUYUM': 'cat_investment',
    'E-TICARET': 'cat_shopping', 'INTERNET': 'cat_shopping',
  };

  CategoryMatch resolve(
    ParsedRecord record, {
    required String counterparty,
    Map<String, String> userRules = const {},
  }) {
    final haystack = TrStatementText.fold('$counterparty ${record.rawDescription}');

    // 1. Kullanıcı kuralları (en uzun kalıp önce)
    if (userRules.isNotEmpty) {
      final rules = userRules.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length));
      for (final r in rules) {
        if (haystack.contains(TrStatementText.fold(r.key))) {
          return CategoryMatch(r.value, sector: record.sector, source: CategorySource.userRule);
        }
      }
    }

    // 2. İşlem türü kategoriyi kesin belirliyorsa
    final byKind = _kindCategories[record.kind];
    if (byKind != null) return CategoryMatch(byKind, sector: record.sector, source: CategorySource.transactionKind);
    if (record.kind == TransactionKind.billPayment) {
      final dict = _lookup(haystack);
      return CategoryMatch(dict?.category ?? 'cat_utilities',
          sector: dict?.sector ?? 'Fatura', brand: dict?.brand, source: CategorySource.transactionKind);
    }

    // 3. Sözlük
    final dict = _lookup(haystack);
    if (dict != null) {
      return CategoryMatch(dict.category, sector: dict.sector, brand: dict.brand, source: CategorySource.dictionary);
    }

    // 4. Yerleşik kurallar
    final builtIn = MerchantSanitizer.resolveCategory(counterparty.isNotEmpty ? counterparty : record.rawDescription);
    if (builtIn != 'cat_general') {
      return CategoryMatch(builtIn, sector: record.sector, source: CategorySource.builtInRule);
    }

    // 5. Bankanın sektör etiketi
    final bankSector = record.sector;
    if (bankSector != null) {
      final folded = TrStatementText.fold(bankSector);
      for (final e in _bankSectors.entries) {
        if (folded.contains(e.key)) return CategoryMatch(e.value, sector: bankSector, source: CategorySource.bankSector);
      }
    }

    final isTransfer = record.kind == TransactionKind.transferIn || record.kind == TransactionKind.transferOut;
    return CategoryMatch(isTransfer ? 'cat_transfer' : 'cat_general', sector: bankSector, source: CategorySource.fallback);
  }

  _DictEntry? _lookup(String haystack) {
    for (final e in _dictionary) {
      if (_containsWord(haystack, e.pattern)) return e;
    }
    return null;
  }

  /// Kalıbın kelime sınırında geçmesi: "BIM" → "BIM R324" eşleşir, "IBIMA" eşleşmez.
  static bool _containsWord(String haystack, String pattern) {
    var index = haystack.indexOf(pattern);
    while (index != -1) {
      final before = index == 0 ? ' ' : haystack[index - 1];
      final afterIndex = index + pattern.length;
      final after = afterIndex >= haystack.length ? ' ' : haystack[afterIndex];
      if (!_isAlnum(before) && !_isAlnum(after)) return true;
      index = haystack.indexOf(pattern, index + 1);
    }
    return false;
  }

  static bool _isAlnum(String ch) => RegExp(r'[A-Z0-9]').hasMatch(ch);
}

class _DictEntry {
  final String pattern;
  final String category;
  final String? sector;
  final String? brand;
  const _DictEntry(this.pattern, this.category, this.sector, this.brand);
}
