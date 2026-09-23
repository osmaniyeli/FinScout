// lib/core/utils/thousands_input_formatter.dart

import 'package:flutter/services.dart';

/// Tutar girişini yazarken Türkçe biçimde gruplar: 1250000 → 1.250.000, kuruş virgülle: 1.250.000,50
/// Ayrıştırma için mevcut CurrencyNormalizer.toMinorUnits bu biçimi zaten okur.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll('.', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');

    final parts = raw.split(',');
    final whole = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
    if (whole.isEmpty && parts.length == 1) return oldValue;
    final decimals = parts.length > 1
        ? parts.sublist(1).join().replaceAll(RegExp(r'[^0-9]'), '')
        : null;

    final grouped = format(whole.isEmpty ? '0' : whole);
    final text = decimals == null
        ? grouped
        : '$grouped,${decimals.length > 2 ? decimals.substring(0, 2) : decimals}';
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  /// "1250000" → "1.250.000"
  static String format(String digits) {
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) buf.write('.');
      buf.write(trimmed[i]);
    }
    return buf.toString();
  }
}
