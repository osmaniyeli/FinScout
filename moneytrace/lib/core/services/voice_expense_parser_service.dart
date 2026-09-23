// lib/core/services/voice_expense_parser_service.dart

import '../../features/quick_entry/presentation/quick_entry_sheet.dart';

class ParsedVoiceExpense {
  final String title;
  final int amountCents;
  final String categoryId;
  final EntryType entryType;
  final String paymentMethod; // 'CASH' or 'CARD'
  final bool isCash;
  final String rawText;

  const ParsedVoiceExpense({
    required this.title,
    required this.amountCents,
    required this.categoryId,
    required this.entryType,
    required this.paymentMethod,
    required this.isCash,
    required this.rawText,
  });
}

class VoiceExpenseParserService {
  static final VoiceExpenseParserService instance =
      VoiceExpenseParserService._internal();
  VoiceExpenseParserService._internal();

  /// Doğal Türkçe ses veya metin girdisini yapılandırılmış harcama verisine çevirir
  ParsedVoiceExpense parseTurkishVoiceInput(String text) {
    final cleaned = text.trim();
    final lower = cleaned.toLowerCase();

    // 1. Tutar Ayrıştırma
    int amountCents = _extractAmountCents(lower);

    // 2. Ödeme Yöntemi Ayrıştırma
    final isCash = lower.contains('nakit') ||
        lower.contains('elden') ||
        lower.contains('peşin');
    final paymentMethod = isCash ? 'CASH' : 'CARD';

    // 3. Kategori ve İşlem Türü Tespiti
    final catInfo = _detectCategoryAndType(lower);
    final categoryId = catInfo.categoryId;
    final entryType = catInfo.entryType;

    // 4. Başlık / Açıklama Temizleme
    final title = _generateCleanTitle(cleaned, categoryId);

    return ParsedVoiceExpense(
      title: title,
      amountCents: amountCents,
      categoryId: categoryId,
      entryType: entryType,
      paymentMethod: paymentMethod,
      isCash: isCash,
      rawText: text,
    );
  }

  int _extractAmountCents(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(' tely', ' tl')
        .replaceAll(' te le', ' tl')
        .replaceAll(' t l', ' tl')
        .trim();

    final verbalKeywords = [
      'bir',
      'iki',
      'üç',
      'uc',
      'dört',
      'dort',
      'beş',
      'bes',
      'altı',
      'alti',
      'yedi',
      'sekiz',
      'dokuz',
      'on',
      'yirmi',
      'otuz',
      'kırk',
      'kirk',
      'elli',
      'altmış',
      'altmis',
      'yetmiş',
      'yetmis',
      'seksen',
      'doksan',
      'yüz',
      'yuz',
      'bin',
      'milyon',
      'buçuk',
      'bucuk',
      'lira',
      'kuruş',
      'kurus'
    ];

    bool containsVerbal =
        verbalKeywords.any((keyword) => cleaned.contains(keyword));

    if (containsVerbal) {
      return _parseVerbalAndNumericToCents(cleaned);
    }

    // Klasik sayısal regex ayrıştırıcı fallback
    final regex = RegExp(r'(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?');
    final match = regex.firstMatch(cleaned);

    if (match != null) {
      final wholePart = match.group(1)?.replaceAll('.', '') ?? '0';
      final decimalPart = match.group(2) ?? '';

      final whole = int.tryParse(wholePart) ?? 0;
      int decimal = 0;
      if (decimalPart.isNotEmpty) {
        decimal = int.tryParse(decimalPart.padRight(2, '0')) ?? 0;
      }
      return (whole * 100) + decimal;
    }

    return 0;
  }

  int _parseVerbalAndNumericToCents(String text) {
    var normalized = text
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g');

    String liraPart = '';
    String kurusPart = '';

    final match = RegExp(r'lira|tl').firstMatch(normalized);
    if (match != null) {
      liraPart = normalized.substring(0, match.start).trim();
      final rest = normalized.substring(match.end).trim();
      final kurusIndex = rest.indexOf('kurus');
      if (kurusIndex != -1) {
        kurusPart = rest.substring(0, kurusIndex).trim();
      } else {
        kurusPart = rest;
      }
    } else {
      final kurusIndex = normalized.indexOf('kurus');
      if (kurusIndex != -1) {
        kurusPart = normalized.substring(0, kurusIndex).trim();
      } else {
        liraPart = normalized;
      }
    }

    int liraCents = 0;
    if (liraPart.isNotEmpty) {
      double liraVal = _parseSingleSegmentToDouble(liraPart);
      liraCents = (liraVal * 100).round();
    }

    int kurusCents = 0;
    if (kurusPart.isNotEmpty) {
      double kurusVal = _parseSingleSegmentToDouble(kurusPart);
      kurusCents = kurusVal.round();
    }

    return liraCents + kurusCents;
  }

  double _parseSingleSegmentToDouble(String segment) {
    final Map<String, double> verbalValues = {
      'sifir': 0,
      'bir': 1,
      'iki': 2,
      'uc': 3,
      'dort': 4,
      'bes': 5,
      'alti': 6,
      'yedi': 7,
      'sekiz': 8,
      'dokuz': 9,
      'on': 10,
      'yirmi': 20,
      'otuz': 30,
      'kirk': 40,
      'elli': 50,
      'altmis': 60,
      'yetmis': 70,
      'seksen': 80,
      'doksan': 90,
      'yuz': 100,
      'bin': 1000,
      'milyon': 1000000,
      'bucuk': 0.5,
    };

    List<String> tokens = [];
    final regExp = RegExp(r'[a-zA-Z]+|\d+(?:[.,]\d+)?');
    for (final match in regExp.allMatches(segment)) {
      tokens.add(match.group(0)!);
    }

    List<double> values = [];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final lowerToken = token.toLowerCase();
      // "bir kahve 85 lira": tanımlık "bir" sayı değildir; yalnızca "bir yüz/bin/milyon/buçuk" içinde 1 sayılır
      if (lowerToken == 'bir') {
        final next = i + 1 < tokens.length ? tokens[i + 1].toLowerCase() : '';
        if (!const {'yuz', 'bin', 'milyon', 'bucuk'}.contains(next)) continue;
      }
      if (verbalValues.containsKey(lowerToken)) {
        values.add(verbalValues[lowerToken]!);
      } else {
        String numStr = lowerToken;
        if (numStr.contains(',') && numStr.contains('.')) {
          numStr = numStr.replaceAll('.', '').replaceAll(',', '.');
        } else if (numStr.contains(',')) {
          numStr = numStr.replaceAll(',', '.');
        } else if (numStr.contains('.')) {
          final parts = numStr.split('.');
          if (parts.length == 2 && parts[1].length == 3) {
            numStr = numStr.replaceAll('.', '');
          }
        }
        final val = double.tryParse(numStr);
        if (val != null) {
          values.add(val);
        }
      }
    }

    if (values.isEmpty) return 0.0;

    double total = 0;
    double current = 0;

    for (var val in values) {
      if (val == 1000000) {
        if (current == 0) current = 1;
        total += current * 1000000;
        current = 0;
      } else if (val == 1000) {
        if (current == 0) current = 1;
        total += current * 1000;
        current = 0;
      } else if (val == 100) {
        if (current == 0) current = 1;
        current = current * 100;
      } else if (val == 0.5) {
        current += 0.5;
      } else {
        current += val;
      }
    }

    return total + current;
  }

  _CategoryResult _detectCategoryAndType(String text) {
    // Gelir Kalıpları
    if (text.contains('maaş') ||
        text.contains('maas') ||
        text.contains('bordro')) {
      return const _CategoryResult('cat_salary', EntryType.income);
    }
    if (text.contains('prim') || text.contains('ikramiye')) {
      return const _CategoryResult('cat_bonus', EntryType.income);
    }
    if (text.contains('kira geldi') ||
        text.contains('kira aldım') ||
        text.contains('kiracı')) {
      return const _CategoryResult('cat_rent_income', EntryType.income);
    }
    if (text.contains('faiz') || text.contains('temettü')) {
      return const _CategoryResult('cat_dividend', EntryType.income);
    }

    // Birikim Kalıpları
    if (text.contains('altın') ||
        text.contains('çeyrek') ||
        text.contains('gram') ||
        text.contains('bilezik')) {
      return const _CategoryResult('cat_gold', EntryType.savings);
    }
    if (text.contains('dolar') ||
        text.contains('euro') ||
        text.contains('döviz') ||
        text.contains('usd') ||
        text.contains('eur')) {
      return const _CategoryResult('cat_fx', EntryType.savings);
    }
    if (text.contains('vadeli') || text.contains('mevduat')) {
      return const _CategoryResult('cat_deposit', EntryType.savings);
    }
    if (text.contains('borsa') ||
        text.contains('hisse') ||
        text.contains('fon') ||
        text.contains('bist')) {
      return const _CategoryResult('cat_stocks', EntryType.savings);
    }
    if (text.contains('bes') || text.contains('bireysel emeklilik')) {
      return const _CategoryResult('cat_bes', EntryType.savings);
    }
    if (text.contains('kripto') ||
        text.contains('bitcoin') ||
        text.contains('btc') ||
        text.contains('eth')) {
      return const _CategoryResult('cat_crypto', EntryType.savings);
    }

    // Gider Kalıpları
    if (text.contains('oto') ||
        text.contains('tamir') ||
        text.contains('sanayi') ||
        text.contains('usta') ||
        text.contains('balata') ||
        text.contains('servis')) {
      return const _CategoryResult('cat_auto_repair', EntryType.expense);
    }
    if (text.contains('benzin') ||
        text.contains('mazot') ||
        text.contains('yakıt') ||
        text.contains('motorin') ||
        text.contains('akaryakıt') ||
        text.contains('shell') ||
        text.contains('opet') ||
        text.contains('bp') ||
        text.contains('taksi') ||
        text.contains('otobüs') ||
        text.contains('metro')) {
      return const _CategoryResult('cat_transit', EntryType.expense);
    }
    if (text.contains('market') ||
        text.contains('bakkal') ||
        text.contains('migros') ||
        text.contains('bim') ||
        text.contains('a101') ||
        text.contains('şok') ||
        text.contains('carrefour') ||
        text.contains('manav') ||
        text.contains('pazar') ||
        text.contains('kasap')) {
      return const _CategoryResult('cat_market', EntryType.expense);
    }
    if (text.contains('kahve') ||
        text.contains('yemek') ||
        text.contains('restoran') ||
        text.contains('lokanta') ||
        text.contains('cafe') ||
        text.contains('kafe') ||
        text.contains('starbucks') ||
        text.contains('burger') ||
        text.contains('pizza') ||
        text.contains('döner') ||
        text.contains('kebap')) {
      return const _CategoryResult('cat_dining', EntryType.expense);
    }
    if (text.contains('netflix') ||
        text.contains('spotify') ||
        text.contains('youtube') ||
        text.contains('abonelik') ||
        text.contains('disney') ||
        text.contains('amazon prime')) {
      return const _CategoryResult('cat_subscriptions', EntryType.expense);
    }
    if (text.contains('fatura') ||
        text.contains('elektrik') ||
        text.contains('su') ||
        text.contains('doğalgaz') ||
        text.contains('dogalgaz') ||
        text.contains('palgaz') ||
        text.contains('igdaş') ||
        text.contains('turkcell') ||
        text.contains('vodafone') ||
        text.contains('telekom') ||
        text.contains('internet')) {
      return const _CategoryResult('cat_utilities', EntryType.expense);
    }
    if (text.contains('eczane') ||
        text.contains('ilaç') ||
        text.contains('hastane') ||
        text.contains('doktor') ||
        text.contains('diş') ||
        text.contains('sağlık')) {
      return const _CategoryResult('cat_health', EntryType.expense);
    }
    if (text.contains('giyim') ||
        text.contains('kıyafet') ||
        text.contains('ayakkabı') ||
        text.contains('pantolon') ||
        text.contains('gömlek') ||
        text.contains('zara') ||
        text.contains('mango') ||
        text.contains('h&m') ||
        text.contains('lcw')) {
      return const _CategoryResult('cat_clothing', EntryType.expense);
    }

    return const _CategoryResult('cat_market', EntryType.expense);
  }

  String _generateCleanTitle(String raw, String categoryId) {
    final lower = raw.toLowerCase();

    // Bilinen işletme / konu adları öncelikli
    if (lower.contains('sanayi') ||
        lower.contains('oto tamir') ||
        lower.contains('tamirci')) return 'Sanayi Oto Tamir';
    if (lower.contains('migros')) return 'Migros';
    if (lower.contains('bim')) return 'BİM';
    if (lower.contains('a101')) return 'A101';
    if (lower.contains('şok')) return 'ŞOK Market';
    if (lower.contains('shell')) return 'Shell Akaryakıt';
    if (lower.contains('opet')) return 'Opet Akaryakıt';
    if (lower.contains('starbucks')) return 'Starbucks';
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('palgaz') || lower.contains('doğalgaz'))
      return 'Doğalgaz Faturası';
    if (lower.contains('elektrik')) return 'Elektrik Faturası';
    if (lower.contains('eczane')) return 'Eczane / İlaç';
    if (lower.contains('maaş')) return 'Aylık Maaş';
    if (lower.contains('kira'))
      return lower.contains('aldım') || lower.contains('geldi')
          ? 'Kira Geliri'
          : 'Kira Ödemesi';
    if (lower.contains('altın')) return 'Altın Alımı';

    // Yedek kategori adı
    switch (categoryId) {
      case 'cat_auto_repair':
        return 'Oto Bakım & Onarım';
      case 'cat_market':
        return 'Market Alışverişi';
      case 'cat_dining':
        return 'Yeme - İçme';
      case 'cat_transit':
        return 'Ulaşım & Akaryakıt';
      case 'cat_subscriptions':
        return 'Abonelik Ödemesi';
      case 'cat_utilities':
        return 'Fatura Ödemesi';
      case 'cat_health':
        return 'Sağlık & Medikal';
      case 'cat_clothing':
        return 'Giyim & Tekstil';
      case 'cat_salary':
        return 'Maaş Geliri';
      case 'cat_bonus':
        return 'Prim Geliri';
      case 'cat_gold':
        return 'Altın / Emtia Yatırımı';
      default:
        return 'Harcama Kaydı';
    }
  }
}

class _CategoryResult {
  final String categoryId;
  final EntryType entryType;
  const _CategoryResult(this.categoryId, this.entryType);
}
