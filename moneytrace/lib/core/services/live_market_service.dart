// lib/core/services/live_market_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class MarketTicker {
  final String symbol; // USD, EUR, ALTIN_GR, CEYREK
  final String name; // ABD Doları, Euro, Gram Altın, Çeyrek Altın
  final double buyingPrice;
  final double sellingPrice;
  final double changeRate; // Günlük % değişim
  final DateTime lastUpdated;

  const MarketTicker({
    required this.symbol,
    required this.name,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.changeRate,
    required this.lastUpdated,
  });

  String get formattedPrice {
    final fixed = sellingPrice.toStringAsFixed(2).split('.');
    final whole = fixed[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '₺$whole,${fixed[1]}';
  }

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'name': name,
        'buying': buyingPrice,
        'selling': sellingPrice,
        'change': changeRate,
        'updated': lastUpdated.toIso8601String(),
      };

  static MarketTicker fromMap(Map<String, dynamic> m) => MarketTicker(
        symbol: m['symbol'] as String,
        name: m['name'] as String,
        buyingPrice: (m['buying'] as num).toDouble(),
        sellingPrice: (m['selling'] as num).toDouble(),
        changeRate: (m['change'] as num).toDouble(),
        lastUpdated: DateTime.parse(m['updated'] as String),
      );
}

/// Herkese açık serbest piyasa kurları (finans.truncgil.com). Kullanıcı verisi gönderilmez.
///
/// Sahte / sabit fiyat yoktur: son başarılı gerçek değerler zaman damgasıyla cihaza yazılır;
/// ağ yoksa onlar gösterilir, hiç veri yoksa ilgili sembol haritada bulunmaz (ekran "—" gösterir).
class LiveMarketService {
  static final LiveMarketService instance = LiveMarketService._internal();
  LiveMarketService._internal();

  static final Uri _endpoint = Uri.parse('https://finans.truncgil.com/v4/today.json');

  /// Uygulamadaki sembol → API anahtarı ve görünen ad
  static const Map<String, (String, String)> _symbols = {
    'USD': ('USD', 'Amerikan Doları'),
    'EUR': ('EUR', 'Euro'),
    'ALTIN_GR': ('GRA', 'Gram Altın'),
    'CEYREK': ('CEYREKALTIN', 'Çeyrek Altın'),
  };

  final Map<String, MarketTicker> _tickers = {};
  bool _cacheLoaded = false;

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/paraiz_market_cache.json');
  }

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      for (final item in list) {
        final t = MarketTicker.fromMap(Map<String, dynamic>.from(item as Map));
        _tickers[t.symbol] = t;
      }
    } catch (e) {
      debugPrint('Kur önbelleği okunamadı: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(_tickers.values.map((t) => t.toMap()).toList()));
    } catch (_) {}
  }

  /// Güncel kurları çeker; başarısız olursa son bilinen gerçek değerleri döndürür.
  Future<Map<String, MarketTicker>> fetchLiveRates() async {
    await _loadCache();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client.getUrl(_endpoint);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final now = DateTime.now();
        var updated = false;

        for (final entry in _symbols.entries) {
          final raw = data[entry.value.$1];
          if (raw is! Map) continue;
          final selling = _parseDouble(raw['Selling']);
          if (selling <= 0) continue;
          _tickers[entry.key] = MarketTicker(
            symbol: entry.key,
            name: entry.value.$2,
            buyingPrice: _parseDouble(raw['Buying']),
            sellingPrice: selling,
            changeRate: _parseDouble(raw['Change'] ?? raw['ChangeRate']),
            lastUpdated: now,
          );
          updated = true;
        }
        if (updated) await _saveCache();
      }
    } catch (e) {
      debugPrint('Canlı kur çekilemedi, son bilinen değerler kullanılıyor: $e');
    } finally {
      client.close();
    }

    return Map.unmodifiable(_tickers);
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    var str = val.toString().replaceAll('%', '').trim();
    // "1.234,56" (TR) ya da "1234.56"
    if (str.contains(',')) str = str.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(str) ?? 0.0;
  }
}
