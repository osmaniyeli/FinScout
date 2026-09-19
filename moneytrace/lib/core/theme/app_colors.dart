import 'package:flutter/material.dart';
import '../config/remote_config_service.dart';

/// "Bright & Crystal FinTech" Resmi Renk Paleti (Statik ve Dinamik Yönetilebilir)
class AppColors {
  // Dinamik Yönetici Paleti Getters
  static Color get dynamicPrimary {
    try {
      final hex = RemoteConfigService.instance.themeConfig.primaryColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return actionPrimary;
    }
  }

  static Color get dynamicIncome {
    try {
      final hex = RemoteConfigService.instance.themeConfig.incomeColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return incomeGreen;
    }
  }

  static Color get dynamicExpense {
    try {
      final hex = RemoteConfigService.instance.themeConfig.expenseColorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return expenseRed;
    }
  }

  // 1. Canvas / Zemin
  static const Color canvasLight = Color(0xFFFFFFFF);
  static const Color canvasDark = Color(0xFF080B11);
  static const Color background = canvasLight;

  // 2. Surface / Yüzey Kartları
  static const Color surfaceLight = Color(0xFFF4F7FE);
  static const Color surfaceDark = Color(0xFF111622);
  static const Color cardSurface = surfaceLight;

  // 3. Border / Çerçeve & Ayraç
  static const Color borderLight = Color(0xFFE3EAF8);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color cardBorder = borderLight;
  static const Color divider = borderLight;

  // 4. Metin Renkleri (Hiyerarşi)
  static const Color textPrimary = Color(0xFF0A0F1D);
  static const Color textSecondary = Color(0xFF4E5D78);
  static const Color textMuted = Color(0xFF8A96A8);

  // Koyu mod metin renkleri
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);

  // 5. Actions / Aksiyonlar
  static const Color actionPrimary = Color(0xFF0052FF); // Elektrik Mavisi
  static const Color primaryGlow = Color(0x470052FF); // rgba(0, 82, 255, 0.28)
  static const Color accentBlue = actionPrimary;

  // 6. Status / Finansal Durum Renkleri
  static const Color incomeGreen = Color(0xFF00D084); // Canlı Zümrüt
  static const Color incomeGreenBg = Color(0xFFE6FAF3);
  static const Color expenseRed = Color(0xFFFF2D55); // Canlı Kızıl Kırmızı
  static const Color expenseRedBg = Color(0xFFFFEAEF);
  static const Color installment = Color(0xFFFF8A00); // Enerjik Turuncu
  static const Color tax = Color(0xFF6366F1); // İndigo / Mor
  static const Color scout = Color(0xFF8B5CF6); // Scout Moru
  static const Color scoutBadgeBg = Color(0xFFF3E8FF);
  static const Color scoutBadgeText = Color(0xFF7C3AED);

  // Prim / VIP Rozet
  static const Color goldPremium = Color(0xFFF59E0B);
  static const Color goldPremiumBg = Color(0xFFFEF3C7);

  // Kategori Renk Kodları (Sistem İçi)
  static const Color catMarket = Color(0xFF00D084);
  static const Color catFuel = Color(0xFFFF8A00);
  static const Color catTransit = Color(0xFF0052FF);
  static const Color catDining = Color(0xFFFF2D55);
  static const Color catSubscriptions = Color(0xFF8B5CF6);
  static const Color catUtilities = Color(0xFF6366F1);
  static const Color catTax = Color(0xFF64748B);
  static const Color catHome = Color(0xFF0284C7);
  static const Color catPet = Color(0xFF0D9488);
  static const Color catKids = Color(0xFFEC4899);
  static const Color catInvestment = Color(0xFFF59E0B);
  static const Color catClothing = Color(0xFF3B82F6);
  static const Color catHealth = Color(0xFF14B8A6);
  static const Color catGeneral = Color(0xFF4E5D78);

  static Color getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'cat_market':
        return catMarket;
      case 'cat_fuel':
        return catFuel;
      case 'cat_transit':
        return catTransit;
      case 'cat_dining':
        return catDining;
      case 'cat_subscriptions':
        return catSubscriptions;
      case 'cat_utilities':
        return catUtilities;
      case 'cat_tax':
        return catTax;
      case 'cat_home':
        return catHome;
      case 'cat_pet':
        return catPet;
      case 'cat_kids':
        return catKids;
      case 'cat_investment':
        return catInvestment;
      case 'cat_clothing':
        return catClothing;
      case 'cat_health':
        return catHealth;
      default:
        return catGeneral;
    }
  }
}
