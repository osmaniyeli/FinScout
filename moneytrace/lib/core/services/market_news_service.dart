// lib/core/services/market_news_service.dart

import 'dart:convert';
import 'dart:io';
import '../models/market_news_item.dart';

class MarketNewsService {
  static final MarketNewsService instance = MarketNewsService._internal();
  MarketNewsService._internal();

  DateTime? _lastFetchTime;
  List<MarketNewsItem> _cachedNews = [];

  // 15 Dakikalık önbellek süresi
  static const Duration cacheDuration = Duration(minutes: 15);

  /// Açık RSS Beslemeleri Kaynakları (Sıfır API Key, %100 Ücretsiz & Yasal)
  static const String bloombergHtRss = 'https://www.bloomberght.com/rss';
  static const String dunyaGazetesiRss = 'https://www.dunya.com/rss';

  /// Güncel Piyasa Haberlerini Getirir
  Future<List<MarketNewsItem>> fetchNews({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // Önbellek geçerliyse doğrudan önbelleği dön
    if (!forceRefresh &&
        _cachedNews.isNotEmpty &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < cacheDuration) {
      return _cachedNews;
    }

    final List<MarketNewsItem> aggregatedNews = [];

    try {
      // 1. Bloomberg HT RSS Çekimi
      final bloombergItems = await _fetchAndParseRss(
        url: bloombergHtRss,
        sourceName: 'Bloomberg HT',
        defaultCategory: 'Piyasa',
      );
      aggregatedNews.addAll(bloombergItems);
    } catch (_) {
      // Ağ hatası durumunda sessizce devam et
    }

    try {
      // 2. Dünya Gazetesi RSS Çekimi
      final dunyaItems = await _fetchAndParseRss(
        url: dunyaGazetesiRss,
        sourceName: 'Dünya Gazetesi',
        defaultCategory: 'Ekonomi',
      );
      aggregatedNews.addAll(dunyaItems);
    } catch (_) {
      // Ağ hatası durumunda sessizce devam et
    }

    if (aggregatedNews.isNotEmpty) {
      // Tarihe göre en yeniden en eskiye sırala
      aggregatedNews.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      _cachedNews = aggregatedNews;
      _lastFetchTime = now;
      return _cachedNews;
    }

    // Ağ yoksa yalnızca daha önce gerçekten çekilmiş haberler gösterilir; uydurma haber yoktur (liste boş olabilir)
    return _cachedNews;
  }

  /// RSS XML İçeriğini HttpClient ile Güvenli İndirir ve Ayrıştırır
  Future<List<MarketNewsItem>> _fetchAndParseRss({
    required String url,
    required String sourceName,
    required String defaultCategory,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (compatible; FinScoutApp/1.0)');
      request.headers.set('Accept', 'application/rss+xml, application/xml, text/xml, */*');

      final response = await request.close();
      if (response.statusCode == 200) {
        final rawXml = await response.transform(utf8.decoder).join();
        return parseRssXml(rawXml, sourceName: sourceName, defaultCategory: defaultCategory);
      }
    } finally {
      client.close();
    }

    return [];
  }

  /// XML String'ini Regex ile Hafif ve Hızlı Ayrıştırır (Sıfır 3. Parti Kütüphane)
  List<MarketNewsItem> parseRssXml(
    String xmlContent, {
    required String sourceName,
    required String defaultCategory,
  }) {
    final List<MarketNewsItem> items = [];
    final itemRegex = RegExp(r'<item>([\s\S]*?)<\/item>', caseSensitive: false);
    final matches = itemRegex.allMatches(xmlContent);

    int count = 0;
    for (final match in matches) {
      if (count >= 10) break; // Kaynak başına maksimum 10 haber al (hafiflik için)

      final itemBody = match.group(1) ?? '';

      final title = _extractTagContent(itemBody, 'title');
      final link = _extractTagContent(itemBody, 'link');
      final descriptionRaw = _extractTagContent(itemBody, 'description');
      final pubDateRaw = _extractTagContent(itemBody, 'pubDate');
      final imageUrl = _extractEnclosureOrImage(itemBody);

      if (title.isNotEmpty) {
        final cleanSummary = _cleanHtmlDescription(descriptionRaw);
        final parsedDate = _parseRssDate(pubDateRaw);

        // Madde 16: Piyasa Gündemi Kategori Filtresi
        // Genel siyaset/magazin/adliye yerine sadece ekonomi, borsa, finans ve ev ekonomisi odaklı içerikler
        if (_isEconomyOrFinanceContent(title, cleanSummary)) {
          items.add(MarketNewsItem(
            id: '${sourceName.toLowerCase()}_${items.length}_${title.hashCode}',
            title: title,
            summary: cleanSummary.isNotEmpty ? cleanSummary : title,
            link: link,
            sourceName: sourceName,
            category: defaultCategory,
            publishedAt: parsedDate,
            imageUrl: imageUrl,
          ));
          count++;
        }
      }
    }

    return items;
  }

  static final List<String> _economyKeywords = [
    'ekonomi', 'borsa', 'bist', 'hisse', 'enflasyon', 'faiz', 'tcmb', 'fed',
    'dolar', 'euro', 'döviz', 'altın', 'kredi', 'mevduat', 'vergi', 'bütçe',
    'tahvil', 'kripto', 'fiyat', 'zam', 'indirim', 'şirket', 'fon', 'ihracat',
    'ithalat', 'piyasa', 'emtia', 'petrol', 'asgari ücret', 'emekli', 'konut',
    'para', 'maliye', 'gelir', 'gider', 'tasarruf', 'finans', 'banka', 'merkez bankası'
  ];

  static bool _isEconomyOrFinanceContent(String title, String summary) {
    final lower = '$title $summary'.toLowerCase();
    for (final kw in _economyKeywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }

  String _extractTagContent(String body, String tag) {
    // CDATA veya düz metin eşleştirme
    final regex = RegExp('<$tag>(?:<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>|([\\s\\S]*?))<\\/$tag>', caseSensitive: false);
    final match = regex.firstMatch(body);
    if (match != null) {
      return (match.group(1) ?? match.group(2) ?? '').trim();
    }
    return '';
  }

  String? _extractEnclosureOrImage(String body) {
    // <enclosure url="..." />
    final enclosureMatch = RegExp(r'<enclosure[^>]+url="([^">]+)"', caseSensitive: false).firstMatch(body);
    if (enclosureMatch != null) return enclosureMatch.group(1);

    // <media:content url="..." />
    final mediaMatch = RegExp(r'<media:content[^>]+url="([^">]+)"', caseSensitive: false).firstMatch(body);
    if (mediaMatch != null) return mediaMatch.group(1);

    return null;
  }

  String _cleanHtmlDescription(String rawHtml) {
    // HTML etiketlerini ve &nbsp; gibi entity'leri temizler
    String text = rawHtml
        .replaceAll(RegExp(r'<[^>]*>', multiLine: true), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 160) {
      return '${text.substring(0, 157)}...';
    }
    return text;
  }

  DateTime _parseRssDate(String pubDate) {
    if (pubDate.isEmpty) return DateTime.now();

    try {
      // RFC-822 / RFC-1123 Tarih Formatı (Örn: "Thu, 18 Sep 2026 14:30:00 +0300")
      final parts = pubDate.split(' ');
      if (parts.length >= 4) {
        final day = int.tryParse(parts[1]) ?? 1;
        final monthStr = parts[2].toLowerCase();
        final year = int.tryParse(parts[3]) ?? DateTime.now().year;

        int month = 1;
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final foundIndex = months.indexOf(monthStr);
        if (foundIndex != -1) month = foundIndex + 1;

        int hour = 12, minute = 0;
        if (parts.length >= 5 && parts[4].contains(':')) {
          final timeParts = parts[4].split(':');
          hour = int.tryParse(timeParts[0]) ?? 12;
          minute = int.tryParse(timeParts[1]) ?? 0;
        }

        return DateTime(year, month, day, hour, minute);
      }
    } catch (_) {}

    return DateTime.tryParse(pubDate) ?? DateTime.now();
  }
}
