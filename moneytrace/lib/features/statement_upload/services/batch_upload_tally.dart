// lib/features/statement_upload/services/batch_upload_tally.dart

/// Toplu PDF yüklemesinin sayaçları ve kullanıcıya gösterilen özet (saf; birim testlenebilir).
///
/// Kural: seçilen her belge özette tam olarak bir kez hesaba katılır — kaydedildi, daha önce
/// eklenmişti ya da neden kaydedilmediği yazılır. Hiçbir belge sessizce kaybolmaz.
class BatchUploadTally {
  BatchUploadTally(this.total);

  /// Seçilen belge sayısı.
  final int total;

  int saved = 0;
  int inserted = 0;
  int duplicates = 0;
  int failed = 0;

  /// Kota/bağlantı nedeniyle hiç denenmeden kalan belgeler (sayı olarak [failed]'a dahil).
  int stoppedByQuota = 0;

  /// Kota/bağlantı durdurduysa sebep (ekranda hata kutusunda gösterilir).
  String? stopReason;
  bool stopIsNetworkError = false;

  final List<String> _notes = [];

  void addSaved(int insertedRows) {
    saved++;
    inserted += insertedRows;
  }

  void addDuplicate() => duplicates++;

  void addFailure(String fileName, String reason) {
    failed++;
    _notes.add('$fileName: $reason');
  }

  /// Kota doldu ya da sunucuya ulaşılamadı: [remaining] belge (şu anki dahil) kaydedilmedi.
  void stop(String reason, {required bool isNetworkError, required int remaining}) {
    stopReason = reason;
    stopIsNetworkError = isNetworkError;
    if (remaining <= 0) return;
    failed += remaining;
    stoppedByQuota += remaining;
    _notes.add(isNetworkError
        ? 'Bağlantı sorunu: $remaining belge kaydedilmedi.'
        : 'Kota doldu: $remaining belge kaydedilmedi.');
  }

  bool get isStopped => stopReason != null;

  /// Hesaba katılan belge sayısı (tutarlılık kontrolü için).
  int get accounted => saved + duplicates + failed;

  List<String> summaryLines() => [
        '$total belgeden $saved tanesi kaydedildi ($inserted işlem).',
        if (duplicates > 0) '$duplicates belge daha önce eklenmişti, atlandı.',
        if (failed > 0) '$failed belge kaydedilmedi:',
        ..._notes,
      ];
}
