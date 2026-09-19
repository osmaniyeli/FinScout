// lib/features/persona_scout/services/scout_persona_insight_engine.dart

enum ScoutMood { happy, alert, surprised, sarcastic, neutral }

class ScoutFeedback {
  final String message;
  final ScoutMood mood;
  final String badgeText;

  const ScoutFeedback({
    required this.message,
    required this.mood,
    required this.badgeText,
  });

  factory ScoutFeedback.initial() {
    return const ScoutFeedback(
      badgeText: 'İzci Nöbette',
      mood: ScoutMood.neutral,
      message: 'Analiz edilecek ekstre veya harcama kaydı aranıyor...',
    );
  }
}

class ScoutPersonaInsightEngine {
  /// Aylık harcama verilerini ve geçmiş trendi kıyaslayarak dinamik geri bildirim üretir.
  static ScoutFeedback generateFeedback({
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
        (currentMonthExpenditureCents / monthlyNetIncomeCents) < 0.70) {
      return ScoutFeedback(
        badgeText: 'Cüzdan Güvende',
        mood: ScoutMood.happy,
        message: isWittyMode
            ? 'Gözlerime inanamıyorum... Ayın sonu yaklaştı ve bütçen hâlâ ekside değil! Git kendine güzel bir kahve ısmarla, benden izin.'
            : 'Tebrikler, bu ay harcamalarınız gelirinizin %70 sınırının altında seyrediyor.',
      );
    }

    // 2. KURAL: Gıda ve Market Tavan Yaptıysa (%25+ Artış)
    if (previousGroceryCents > 0 && currentGroceryCents > (previousGroceryCents * 1.25)) {
      return ScoutFeedback(
        badgeText: 'Mutfakta Yangın Var',
        mood: ScoutMood.surprised,
        message: isWittyMode
            ? 'Bu ay mutfakta şenlik var! Gıda harcamaların tavan yapmış; ya eve gizli bir ordu taşındı ya da misafirlerin kapıyı aşındırdı.'
            : 'Market ve gıda harcamalarınız geçen aya kıyasla %25 üzerinde artış gösterdi.',
      );
    }

    // 3. KURAL: Yakıt ve Taksi Coştuysa (%25+ Artış)
    if (previousFuelCents > 0 && currentFuelCents > (previousFuelCents * 1.25)) {
      return ScoutFeedback(
        badgeText: 'Depo Alev Aldı',
        mood: ScoutMood.sarcastic,
        message: isWittyMode
            ? 'Depo yine fullenmiş, taksiler durmamış! Bu tempoyla yakında seni uzay istasyonundan toplayacağız. Yürümek de bir seçenekti hani!'
            : 'Ulaşım ve akaryakıt harcamalarınız dönemsel bütçenizi zorlamaktadır.',
      );
    }

    // 4. KURAL: Taksit Blokajı Gelirin %40'ını Aştıysa
    if (monthlyNetIncomeCents > 0 && 
        (futureCommittedInstallmentsCents / monthlyNetIncomeCents) > 0.40) {
      return ScoutFeedback(
        badgeText: 'Taksit Dağı',
        mood: ScoutMood.alert,
        message: isWittyMode
            ? 'Önümüzdeki 4 ayın harcamasını şimdiden afiyetle yemişsin! Gelecekteki sen şu an sana pek de hoş bakmıyor.'
            : 'Gelecek dönem taksitli borç yükünüz aylık gelirinizin %40 kritik eşiğini aştı.',
      );
    }

    // 5. KURAL: Vergi Şampiyonu
    if (stateShareRatio > 20.0) {
      return ScoutFeedback(
        badgeText: 'Vergi Şampiyonu',
        mood: ScoutMood.sarcastic,
        message: isWittyMode
            ? 'Gözlerini kapat, burası biraz can yakabilir! Bu ay da bütçenle ülkeye can suyu oldun. Cebinden çıkan her 5 liranın 1 lirası kamuya aktı.'
            : 'Bu dönem ödenen doğrudan ve dolaylı vergi payı %${stateShareRatio.toStringAsFixed(1)} seviyesindedir.',
      );
    }

    return const ScoutFeedback(
      badgeText: 'Dengeli Seyir',
      mood: ScoutMood.neutral,
      message: 'Harcama tempon kontrol altında görünüyor. Ay sonuna kadar disiplini elden bırakma!',
    );
  }
}
