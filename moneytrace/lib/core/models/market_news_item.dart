// lib/core/models/market_news_item.dart

class MarketNewsItem {
  final String id;
  final String title;
  final String summary;
  final String link;
  final String sourceName; // Örn: 'Bloomberg HT', 'Dünya Gazetesi', 'NTV Para'
  final String category; // 'Borsa', 'Döviz', 'Emtia', 'Makro', 'Genel'
  final DateTime publishedAt;
  final String? imageUrl;

  const MarketNewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.link,
    required this.sourceName,
    this.category = 'Piyasa',
    required this.publishedAt,
    this.imageUrl,
  });

  /// Kullanıcı dostu göreceli zaman ("12 dk önce", "2 saat önce")
  String get timeAgoFormatted {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${publishedAt.day}.${publishedAt.month}.${publishedAt.year}';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'link': link,
      'sourceName': sourceName,
      'category': category,
      'publishedAt': publishedAt.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  factory MarketNewsItem.fromMap(Map<String, dynamic> map) {
    return MarketNewsItem(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      link: map['link'] as String? ?? '',
      sourceName: map['sourceName'] as String? ?? 'Piyasa',
      category: map['category'] as String? ?? 'Genel',
      publishedAt: DateTime.tryParse(map['publishedAt'] as String? ?? '') ?? DateTime.now(),
      imageUrl: map['imageUrl'] as String?,
    );
  }
}
