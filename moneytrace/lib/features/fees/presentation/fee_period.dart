// lib/features/fees/presentation/fee_period.dart

/// Masraflar dönemi: takvim ayı ([month] dolu) ya da takvim yılı ([month] null; 1 Ocak'tan bugüne).
class FeePeriod {
  final int year;
  final int? month;

  const FeePeriod({required this.year, this.month});

  factory FeePeriod.thisMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return FeePeriod(year: n.year, month: n.month);
  }

  factory FeePeriod.thisYear([DateTime? now]) =>
      FeePeriod(year: (now ?? DateTime.now()).year);

  bool get isYear => month == null;

  DateTime get from => DateTime(year, month ?? 1, 1);
  DateTime get to =>
      month == null ? DateTime(year + 1, 1, 1) : DateTime(year, month! + 1, 1);

  FeePeriod get previous {
    final m = month;
    if (m == null) return FeePeriod(year: year - 1);
    return m == 1
        ? FeePeriod(year: year - 1, month: 12)
        : FeePeriod(year: year, month: m - 1);
  }

  FeePeriod get next {
    final m = month;
    if (m == null) return FeePeriod(year: year + 1);
    return m == 12
        ? FeePeriod(year: year + 1, month: 1)
        : FeePeriod(year: year, month: m + 1);
  }

  /// Gelecekteki döneme geçilmez.
  bool canGoNext([DateTime? now]) {
    return !next.from.isAfter(now ?? DateTime.now());
  }

  static const monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];

  /// "Eylül 2026" ya da "2026 (1 Ocak – bugün)"
  String get label {
    final m = month;
    if (m == null) {
      final n = DateTime.now();
      return year == n.year ? '$year (1 Ocak – bugün)' : '$year';
    }
    return '${monthNames[m - 1]} $year';
  }

  @override
  bool operator ==(Object other) =>
      other is FeePeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// 05.09.2026
String formatFeeDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
