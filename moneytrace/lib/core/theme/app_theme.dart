import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double card = 16.0;
  static const double button = 14.0;
  static const double sheet = 24.0;
  static const double pill = 99.0;
}

class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x060F172A),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x04000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      // 1. Ana Marka Fontu: Plus Jakarta Sans
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        // Başlıklar
        displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        // Gövde Metinleri
        bodyLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.actionPrimary,
        surface: AppColors.cardSurface,
        onSurface: AppColors.textPrimary,
        background: AppColors.background,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // 2. Finansal Rakamlar ve Tutarlar İçin Yardımcı Stil
  static TextStyle get numericStyle => GoogleFonts.jetBrainsMono(
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
}

