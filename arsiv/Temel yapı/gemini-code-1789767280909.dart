// DOSYA ADI: 07_TAX_calculator_service.dart
// HEDEF DİZİN: lib/features/tax_analytics/services/07_TAX_calculator_service.dart

class TaxBreakdown {
  final int directTaxesCents;    // Bordrodan gelen Gelir/Damga Vergisi
  final int financialLeviesCents;// Kredi BSMV + KKDF
  final int officialFeesCents;   // MTV, Harçlar
  final int estimatedVatCents;   // Harcamalardan doğan tahmini KDV
  final int totalStateShareCents;// Toplam Kamuya Giden Pay
  final double stateShareRatio;  // Harcamalara/Gelire oranı (%)

  TaxBreakdown({
    required this.directTaxesCents,
    required this.financialLeviesCents,
    required this.officialFeesCents,
    required this.estimatedVatCents,
    required this.totalStateShareCents,
    required this.stateShareRatio,
  });
}

class TaxCalculatorService {
  /// İşlem listesini ve bordro verilerini tarayarak toplam vergi yükünü çıkarır.
  TaxBreakdown calculateMonthlyTaxLoad({
    required List<Map<String, dynamic>> transactions,
    int directPayrollTaxesCents = 0,
    required int totalExpenditureCents,
  }) {
    int financialLevies = 0;
    int officialFees = 0;
    int estimatedVat = 0;

    for (final tx in transactions) {
      final String category = tx['category_id'] ?? '';
      final String desc = (tx['raw_description'] ?? '').toString().toUpperCase();
      final int amount = (tx['billing_amount_cents'] ?? 0) as int;

      // 1. Kredi ve Bankacılık Fonları (BSMV & KKDF)
      if (desc.contains('BSMV') || desc.contains('KKDF')) {
        financialLevies += amount;
      }

      // 2. Resmi Harçlar ve Motorlu Taşıtlar Vergisi (MTV)
      else if (category == 'cat_tax' || desc.contains('VERGİ DAİRESİ') || desc.contains('MOTORLU TASITLAR')) {
        officialFees += amount;
      }

      // 3. Tüketimden Doğan Tahmini KDV Hesabı (Kategori bazlı varsayılan oranlar)
      else if (category == 'cat_fuel') {
        // Akaryakıt: ~%20 KDV payı
        estimatedVat += (amount * 0.20 / 1.20).round();
      } else if (category == 'cat_dining') {
        // Restoran/Yeme-İçme: ~%10 KDV payı
        estimatedVat += (amount * 0.10 / 1.10).round();
      } else if (category == 'cat_market') {
        // Temel Gıda & Market: Ağırlıklı ortalama ~%1 - %10 arası (varsayılan %8)
        estimatedVat += (amount * 0.08 / 1.08).round();
      }
    }

    final int totalStateShare = directPayrollTaxesCents + financialLevies + officialFees + estimatedVat;
    final double ratio = totalExpenditureCents > 0
        ? (totalStateShare / totalExpenditureCents) * 100
        : 0.0;

    return TaxBreakdown(
      directTaxesCents: directPayrollTaxesCents,
      financialLeviesCents: financialLevies,
      officialFeesCents: officialFees,
      estimatedVatCents: estimatedVat,
      totalStateShareCents: totalStateShare,
      stateShareRatio: double.parse(ratio.toStringAsFixed(1)),
    );
  }
}