// test/market_calculator_test.dart
//
// Görev 4 — piyasa hesaplama asistanı (MarketNewsSection._buildCalculator): kullanıcı miktar
// girip varlık seçince LiveMarketService'ten gelen GERÇEK kurla (uydurma/sabit değer değil)
// TL karşılığını hesaplar. Ağ erişimi olmayan test ortamında LiveMarketService.fetchLiveRates()
// önce _loadCache() ile diskteki son bilinen gerçek kuru okur; ağ isteği başarısız olsa bile o
// önbellek döner (bkz. live_market_service.dart) — bu test o deterministik yolu kullanır.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:moneytrace/features/assets_portfolio/presentation/widgets/market_news_section.dart';

class _TempDirPathProvider extends PathProviderPlatform {
  final String path;
  _TempDirPathProvider(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Gerçek zaman geçmesi gerekiyor (dosya I/O + HttpClient'in başarısız ağ isteğinden dönüşü);
/// bkz. test/bank_selection_sheet_test.dart._pumpUntil ile aynı desen.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition() && stopwatch.elapsed < timeout) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finscout_market_calc_test_');
    PathProviderPlatform.instance = _TempDirPathProvider(tempDir.path);

    // LiveMarketService'in beklediği önbellek biçimi (bkz. MarketTicker.toMap/fromMap).
    final cacheFile = File('${tempDir.path}/paraiz_market_cache.json');
    await cacheFile.writeAsString(jsonEncode([
      {
        'symbol': 'USD',
        'name': 'Amerikan Doları',
        'buying': 41.50,
        'selling': 41.80,
        'change': 0.0,
        'updated': DateTime.now().toIso8601String(),
      },
    ]));
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('5 USD girilince önbellekteki GERÇEK alış kuruyla doğru TL karşılığını hesaplar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketNewsSection())),
    ));
    await tester.pump();

    await tester.runAsync(() async {
      // Varlık seçimini USD'ye çevir (önbellekte yalnız USD kaydı var).
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.tap(find.text('USD').last);
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '5');
      await tester.pump();

      await _pumpUntil(tester, () => find.textContaining('≈').evaluate().isNotEmpty);
    });

    // 5 USD * 41,50 ₺ (önbellekteki alış kuru) = 207,50 ₺ — uydurma sabit değer değil, gerçek
    // MarketTicker.buyingPrice'tan çarpılır (bkz. _buildCalculator).
    expect(find.text('≈ ₺207,50'), findsOneWidget);
  });

  testWidgets('Miktar girilmeden yer tutucu bilgi metni gösterilir, hayali sonuç yazılmaz',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketNewsSection())),
    ));
    await tester.pump();

    expect(find.text('Miktar gir, güncel kurla TL karşılığını gör.'), findsOneWidget);
    expect(find.textContaining('≈'), findsNothing);
  });
}
