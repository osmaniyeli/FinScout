// lib/core/widgets/bank_logo.dart

import 'package:flutter/material.dart';

/// Banka kimliği: dosya adı (slug), kurumsal renk ve baş harf rozeti.
class BankBrand {
  final String slug; // assets/banks/<slug>.png
  final String initials;
  final Color color;
  const BankBrand(this.slug, this.initials, this.color);

  /// Banka adını eşleştirme için sadeleştirir: "Türkiye İş Bankası A.Ş." → "turkiye is bankasi a s"
  static String fold(String name) {
    const tr = {
      'ı': 'i', 'İ': 'i', 'I': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
      'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
    };
    final b = StringBuffer();
    for (final ch in name.split('')) {
      b.write(tr[ch] ?? ch.toLowerCase());
    }
    return b
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static const _yapiKredi = BankBrand('yapi_kredi', 'YK', Color(0xFF004990));
  static const _garanti = BankBrand('garanti', 'GB', Color(0xFF1B8A4B));
  static const _akbank = BankBrand('akbank', 'AK', Color(0xFFDC0005));
  static const _enpara = BankBrand('enpara', 'EN', Color(0xFF6F2C91));
  static const _isBankasi = BankBrand('is_bankasi', 'İŞ', Color(0xFF0A3C8C));
  static const _ziraat = BankBrand('ziraat', 'ZB', Color(0xFFE30A17));
  static const _halkbank = BankBrand('halkbank', 'HB', Color(0xFF0066B3));
  static const _vakifbank = BankBrand('vakifbank', 'VB', Color(0xFFFDB913));
  static const _qnb = BankBrand('qnb', 'QNB', Color(0xFF5B2C83));

  /// Banka adından marka bulur; tanınmayan bankada null.
  static BankBrand? of(String? bankName) {
    if (bankName == null) return null;
    final f = fold(bankName);
    final compact = f.replaceAll(' ', '');
    if (f.isEmpty) return null;
    if (compact.contains('yapikredi') || RegExp(r'(^| )ykb( |$)').hasMatch(f)) {
      return _yapiKredi;
    }
    if (compact.contains('garanti')) return _garanti;
    if (compact.contains('akbank')) return _akbank;
    if (compact.contains('enpara')) return _enpara;
    if (compact.contains('ziraat')) return _ziraat;
    if (compact.contains('halkbank') || RegExp(r'(^| )halk( |$)').hasMatch(f)) {
      return _halkbank;
    }
    if (compact.contains('vakif')) return _vakifbank;
    if (compact.contains('qnb') || compact.contains('finansbank')) return _qnb;
    if (compact.contains('isbank') || RegExp(r'(^| )is( |$)').hasMatch(f)) {
      return _isBankasi;
    }
    return null;
  }

  /// Tanınmayan banka için adın baş harfleri (en çok 2).
  static String initialsOf(String bankName) {
    final words = bankName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(w[0]))
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first[0].toUpperCase();
    return words.length > 1 ? '$first${words[1][0].toUpperCase()}' : first;
  }
}

/// Banka logosu: `assets/banks/<slug>.png` varsa onu, yoksa bankanın kurumsal renginde baş harf rozeti.
class BankLogo extends StatelessWidget {
  final String? bankName;
  final double size;

  const BankLogo({super.key, required this.bankName, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final brand = BankBrand.of(bankName);
    final radius = BorderRadius.circular(size * 0.28);
    final badge = _InitialsBadge(
      text: brand?.initials ??
          ((bankName ?? '').trim().isEmpty
              ? '?'
              : BankBrand.initialsOf(bankName!)),
      color: brand?.color ?? const Color(0xFF64748B),
      size: size,
      radius: radius,
    );
    if (brand == null) return badge;
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        'assets/banks/${brand.slug}.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Logo dosyası henüz eklenmemişse rozet gösterilir.
        errorBuilder: (_, __, ___) => badge,
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final BorderRadius radius;

  const _InitialsBadge({
    required this.text,
    required this.color,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final onColor =
        color.computeLuminance() > 0.5 ? const Color(0xFF111827) : Colors.white;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: onColor,
          fontSize: size * (text.length > 2 ? 0.28 : 0.36),
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
