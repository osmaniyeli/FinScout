// DOSYA ADI: 08_SCOUT_persona_insight_engine.dart
// HEDEF DİZİN: lib/features/persona_scout/services/08_SCOUT_persona_insight_engine.dart

enum ScoutMood { happy, alert, surprised, sarcastic, neutral }

class ScoutFeedback {
  final String message;
  final ScoutMood mood;
  final String badgeText;

  ScoutFeedback({
    required this.message,
    required this.mood,
    required this.badgeText,
  });
}

class ScoutPersonaInsightEngine {
  /// Aylık harcama verilerini ve geçmiş trendi kıyaslayarak dinamik geri bildirim üretir.
  ScoutFeedback generateFeedback({
    required int currentMonthExpenditureCents,
    required int previousMonthExpenditureCents,
    required int currentGroceryCents,
    required int previousGroceryCents,
    required int currentFuelCents,
    required int previousFuelCents,
    required int futureCommittedInstallmentsCents,
    required int monthlyNetIncomeCents,
    required double stateShareRatio,
    bool isWittyMode = true,
  }) {
    // 1. KURAL: Bütçe Dengesi ve Tasarruf (Ödüllendirme)
    if (currentMonthExpenditureCents > 0 && 
        monthlyNetIncomeCents > 0 && 
        (currentMonthExpenditureCents / monthlyNetIncomeCents) < 0.60) {
      return ScoutFeedback(
        badgeText: 'Cüzdan Güvende',
        mood: ScoutMood.happy,
        message: isWittyMode
            ? 'Gözlerime inanamıyorum... Ayın sonu yaklaştı ve bütçen hâlâ ekside değil! Git kendine güzel bir kahve ısmarla, benden izin.'
            : 'Tebrikler, bu ay harcamalarınız gelirinizin %60 sınırının altında seyrediyor.',
      );
    }

    // 2. KURAL: Gıda ve Market Tavan Yaptıysa (%25+ Artış)
    if (previousGroceryCents > 0 && currentGroceryCents > (previousGroceryCents * 1.25)) {
      return ScoutFeedback(
        badgeText: 'Mutfakta Yangın Var',
        mood: ScoutMood.surprised,
        message: isWittyMode
            ? 'Bu ay mutfakta şenlik var! Gıda harcamaların tavan yapmış; ya eve gizli bir ordu taşındı ya da misafirlerin kapıyı aşındırdı.'
            : 'Market ve bakkaliye harcamalarınız geçen aya kıyasla %25 üzerinde artış gösterdi.',
      );
    }

    // 3. KURAL: Yakıt ve Taksi Coştuysa (%25+ Artış)
    if (previousFuelCents > 0 && currentFuelCents > (previousFuelCents * 1.25)) {
      return ScoutFeedback(
        badgeText: 'Depo Alev Aldı',
        mood: ScoutMood.sarcastic,
        message: isWittyMode
            ? 'Depo yine fullenmiş, taksiler durmamış! Bu tempoyla gidersen yakında seni uzay istasyonundan toplayacağız. Yürümek de bir seçenekti hani!'
            : 'Ulaşım ve akaryakıt giderlerinizde geçen aya göre belirgin bir artış tespit edildi.',
      );
    }

    // 4. KURAL: Taksit Blokajı (Gelecek borç yükü aylık net gelirin %40'ını aştıysa)
    if (monthlyNetIncomeCents > 0 && (futureCommittedInstallmentsCents / monthlyNetIncomeCents) > 0.40) {
      return ScoutFeedback(
        badgeText: 'Gelecek İpotek Altında',
        mood: ScoutMood.alert,
        message: isWittyMode
            ? 'Önümüzdeki ayların parasını şimdiden afiyetle yemişsin. Taksitler dağ olmuş, gelecekteki sen şu an sana pek de hoş bakmıyor!'
            : 'Önümüzdeki dönemlere sarkan kesinleşmiş taksit yükünüz aylık gelirinizin %40 sınırını aşmıştır.',
      );
    }

    // 5. KURAL: Yüksek Vergi ve Harç Yükü (%20+)
    if (stateShareRatio >= 20.0) {
      return ScoutFeedback(
        badgeText: 'Ekonominin Gizli Kahramanı',
        mood: ScoutMood.neutral,
        message: isWittyMode
            ? 'Gözlerini kapat, burası biraz can yakabilir! Bu ay harcamalarının %$stateShareRatio\'si doğrudan vergiye, fonlara ve devlete gitti. Resmen ülkeye can suyu oldun.'
            : 'Bu dönem toplam harcamalarınızın %$stateShareRatio kadarı doğrudan ve dolaylı vergi kesintilerinden oluşmaktadır.',
      );
    }

    // Varsayılan Normal Durum
    return ScoutFeedback(
      badgeText: 'İzci Nöbette',
      mood: ScoutMood.neutral,
      message: isWittyMode
          ? 'Cüzdanda olağanüstü bir hareket yok. Rakamların izini sürmeye devam ediyorum, gözüm üzerinde!'
          : 'Harcamalarınız aylık standart ortalamalar dahilinde devam etmektedir.',
    );
  }
}