// lib/core/theme/app_silhouette_icons.dart

import 'package:flutter/material.dart';

/// FinTech standardında tek renkli, yüksek kontrastlı silüet ikon bileşeni.
/// Kart ve butonların zemin rengine göre siyah veya beyaz silüet çizer.
class SilhouetteIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final double padding;
  final double borderRadius;
  final bool isDarkBackground;

  const SilhouetteIcon({
    Key? key,
    required this.icon,
    this.size = 22,
    this.color,
    this.backgroundColor,
    this.padding = 10,
    this.borderRadius = 14,
    this.isDarkBackground = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Silüet kuralı: Koyu zeminde saf beyaz, açık zeminde saf siyah/koyu arduvaz
    final Color iconColor = color ?? (isDarkBackground ? Colors.white : const Color(0xFF0A0F1D));
    final Color bg = backgroundColor ?? (isDarkBackground ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9));

    return Container(
      width: size + (padding * 2),
      height: size + (padding * 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size,
          color: iconColor,
        ),
      ),
    );
  }
}

/// Siyah-Beyaz Silüet İkon Kütüphanesi
class AppSilhouetteIcons {
  // Hedefler Modülü Silüetleri (Siyah/Beyaz)
  static const IconData vehicle = Icons.directions_car_filled_rounded;
  static const IconData house = Icons.home_filled;
  static const IconData motorcycle = Icons.two_wheeler_rounded;
  static const IconData boat = Icons.directions_boat_filled_rounded;
  static const IconData gift = Icons.card_giftcard_rounded;
  static const IconData travel = Icons.flight_takeoff_rounded;
  static const IconData electronics = Icons.devices_other_rounded;
  static const IconData savings = Icons.savings_rounded;

  // Harcama & Kategori Silüetleri
  static const IconData market = Icons.shopping_bag_rounded;
  static const IconData fuel = Icons.local_gas_station_rounded;
  static const IconData transit = Icons.commute_rounded;
  static const IconData dining = Icons.restaurant_rounded;
  static const IconData subscription = Icons.subscriptions_rounded;
  static const IconData utility = Icons.receipt_long_rounded;
  static const IconData tax = Icons.account_balance_rounded;
  static const IconData salary = Icons.payments_rounded;
  static const IconData clothing = Icons.checkroom_rounded;
  static const IconData health = Icons.medical_services_rounded;
  static const IconData investment = Icons.trending_up_rounded;

  // Genel Aksiyon Silüetleri
  static const IconData uploadPdf = Icons.picture_as_pdf_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData check = Icons.check_circle_rounded;
  static const IconData wallet = Icons.account_balance_wallet_rounded;
}
