import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/core/services/voice_expense_parser_service.dart';

void main() {
  group('VoiceExpenseParserService Testleri', () {
    final parser = VoiceExpenseParserService.instance;

    test('Sözlü Türkçe Sayı Analizleri (Doğal Dil)', () {
      // "üç bin beş yüz" = 3500.00 Lira -> 350000 cents
      expect(
        parser.parseTurkishVoiceInput("Sanayide üç bin beş yüz harcadım").amountCents,
        350000,
      );

      // "iki buçuk" = 2.5 Lira -> 250 cents
      expect(
        parser.parseTurkishVoiceInput("Kahveye iki buçuk lira verdim").amountCents,
        250,
      );

      // "yüz elli" = 150.00 Lira -> 15000 cents
      expect(
        parser.parseTurkishVoiceInput("Manav yüz elli tuttu").amountCents,
        15000,
      );

      // "bin iki yüz" = 1200.00 Lira -> 120000 cents
      expect(
        parser.parseTurkishVoiceInput("Yemek bin iki yüz lira").amountCents,
        120000,
      );

      // "kırk beş lira elli kuruş" = 45.50 Lira -> 4550 cents
      expect(
        parser.parseTurkishVoiceInput("Giyim kırk beş lira elli kuruş").amountCents,
        4550,
      );
    });

    test('Tanımlık "bir" ve sayı sanılan kelimeler tutarı bozmaz', () {
      expect(parser.parseTurkishVoiceInput("Bir kahve 85 lira").amountCents, 8500);
      expect(parser.parseTurkishVoiceInput("Netflix abonelik 149 TL").amountCents, 14900);
      expect(parser.parseTurkishVoiceInput("Bir buçuk lira sakız").amountCents, 150);
    });

    test('Rakamlı ve Karışık Biçimli Analizler', () {
      // "1.850 TL" -> 185000 cents
      expect(
        parser.parseTurkishVoiceInput("Shell benzin 1.850 TL aldım").amountCents,
        185000,
      );

      // "3.500" -> 350000 cents
      expect(
        parser.parseTurkishVoiceInput("Sanayide 3.500 ödedim").amountCents,
        350000,
      );

      // "185,50" -> 18550 cents
      expect(
        parser.parseTurkishVoiceInput("Starbucks kahve 185,50 lira").amountCents,
        18550,
      );
    });
  });
}
