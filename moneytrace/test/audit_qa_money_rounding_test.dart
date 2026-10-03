// test/audit_qa_money_rounding_test.dart
//
// DENETİM (QA 3/5) — Para / yuvarlama: CurrencyNormalizer.toMinorUnits (ekstre hücreleri ve TÜM elle
// tutar girişleri: hızlı giriş, hedef, kart ödemesi, varlık) ve formatCents (ekranda/bildirimde gösterim).
// Önceden doğrudan birim testi yoktu. Kuruş tamsayısı → metin → kuruş tur-dönüşü kayıpsız olmalı;
// ThousandsInputFormatter'ın ürettiği Türkçe biçimler doğru okunmalı; ikili kayan nokta (0,29 gibi)
// kuruş kaybettirmemeli.

import 'package:flutter_test/flutter_test.dart';

import 'package:moneytrace/core/utils/currency_normalizer.dart';
import 'package:moneytrace/core/utils/thousands_input_formatter.dart';

String _typed(String keystrokes) {
  const f = ThousandsInputFormatter();
  var value = TextEditingValue.empty;
  for (final ch in keystrokes.split('')) {
    value = f.formatEditUpdate(value, TextEditingValue(text: value.text + ch));
  }
  return value.text;
}

void main() {
  group('CurrencyNormalizer.formatCents', () {
    test('Türkçe biçim: binlik nokta, kuruş virgül, işaret ve sıfır', () {
      expect(CurrencyNormalizer.formatCents(0), '₺0,00');
      expect(CurrencyNormalizer.formatCents(5), '₺0,05');
      expect(CurrencyNormalizer.formatCents(125050), '₺1.250,50');
      expect(CurrencyNormalizer.formatCents(100000000), '₺1.000.000,00');
      expect(CurrencyNormalizer.formatCents(-99), '-₺0,99');
      expect(CurrencyNormalizer.formatCents(4500, showSign: true), '+₺45,00');
      expect(CurrencyNormalizer.formatCents(4500, currency: 'USD'), r'$45,00');
    });
  });

  group('CurrencyNormalizer.toMinorUnits', () {
    test('ekstre/elle giriş biçimleri', () {
      expect(CurrencyNormalizer.toMinorUnits('1.637,38 TL'), 163738);
      expect(CurrencyNormalizer.toMinorUnits('+18.237,58'), 1823758);
      expect(CurrencyNormalizer.toMinorUnits('-30.000,00 TL'), -3000000);
      expect(CurrencyNormalizer.toMinorUnits('363,84'), 36384);
      expect(CurrencyNormalizer.toMinorUnits('76.000'), 7600000,
          reason: '3 haneli nokta binlik ayracıdır');
      expect(CurrencyNormalizer.toMinorUnits('1.500.000'), 150000000);
      expect(CurrencyNormalizer.toMinorUnits('76.50'), 7650);
      expect(CurrencyNormalizer.toMinorUnits('₺ 12'), 1200);
      expect(CurrencyNormalizer.toMinorUnits(''), 0);
      expect(CurrencyNormalizer.toMinorUnits('abc'), 0);
    });

    test('kayan nokta kuruş kaybettirmez: 0,01…9,99 ve tipik "kötü" değerler',
        () {
      for (var c = 1; c < 1000; c++) {
        final s = '${c ~/ 100},${(c % 100).toString().padLeft(2, '0')}';
        expect(CurrencyNormalizer.toMinorUnits(s), c, reason: s);
      }
      for (final (s, c) in [
        ('0,29', 29),
        ('1,13', 113),
        ('4,35', 435),
        ('1.005,15', 100515),
        ('8.091,04', 809104)
      ]) {
        expect(CurrencyNormalizer.toMinorUnits(s), c, reason: s);
      }
    });

    test(
        'tur-dönüşü: formatCents → toMinorUnits kayıpsız (−10 milyar … +10 milyar TL örnekleri)',
        () {
      final samples = <int>[
        0,
        1,
        99,
        100,
        101,
        999999,
        1000000,
        123456789,
        2147483647,
        2147483648,
        99999999999,
        100000000000,
        1000000000000,
        -1,
        -12345,
        -1000000000000,
      ];
      for (var i = 1; i < 2000; i++) {
        samples.add(i * 7919 * 1013);
      }
      for (final c in samples) {
        final text = CurrencyNormalizer.formatCents(c);
        expect(CurrencyNormalizer.toMinorUnits(text), c, reason: text);
      }
    });

    test(
        'ThousandsInputFormatter ile yazılan tutar doğru kuruşa çevrilir (hızlı giriş/hedef akışı)',
        () {
      expect(_typed('1250000'), '1.250.000');
      expect(CurrencyNormalizer.toMinorUnits(_typed('1250000')), 125000000);
      expect(_typed('1250,5'), '1.250,5');
      expect(CurrencyNormalizer.toMinorUnits(_typed('1250,5')), 125050);
      expect(_typed('99,999'), '99,99', reason: 'kuruş 2 haneyle sınırlı');
      expect(CurrencyNormalizer.toMinorUnits(_typed('99,999')), 9999);
      expect(CurrencyNormalizer.toMinorUnits(_typed('1000')), 100000,
          reason: '"1.000" binlik olarak okunmalı');
      expect(CurrencyNormalizer.toMinorUnits(_typed('0,5')), 50);
    });

    test(
      'belgelenen "1,155.00" (ABD biçimi) 1.155,00 TL olarak okunur',
      () {
        expect(CurrencyNormalizer.toMinorUnits('1,155.00'), 115500);
      },
      skip:
          'BULGU QA-P3-05: CurrencyNormalizer.toMinorUnits doc yorumu "1,155.00" biçimini desteklediğini söylüyor; '
          'gerçekte hem nokta hem virgül görünce TR biçimi varsayıp 116 kuruş (1,16 TL) döndürüyor (1000 kat hata). '
          'Bugün TR ekstre regex\'i ve ThousandsInputFormatter bu girdiyi üretmediğinden etkisi düşük; '
          'yabancı para/USD ekstresi eklenirse ya da biçimlendiricisiz bir alana yapıştırılırsa gerçek hataya dönüşür.',
    );
  });
}
