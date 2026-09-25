// test/batch_upload_tally_test.dart
//
// Toplu PDF yüklemesi özeti: seçilen her belge tam bir kez hesaba katılır, hiçbiri sessizce kaybolmaz.

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytrace/features/statement_upload/services/batch_upload_tally.dart';

void main() {
  test('kaydedilen, mükerrer ve hatalı belgeler özetlenir', () {
    final t = BatchUploadTally(4)
      ..addSaved(12)
      ..addSaved(3)
      ..addDuplicate()
      ..addFailure('c.pdf', 'dosya okunamadı');
    expect(t.accounted, 4);
    expect(t.isStopped, isFalse);
    expect(t.summaryLines(), [
      '4 belgeden 2 tanesi kaydedildi (15 işlem).',
      '1 belge daha önce eklenmişti, atlandı.',
      '1 belge kaydedilmedi:',
      'c.pdf: dosya okunamadı',
    ]);
  });

  test('kota dolunca kalanlar ve onay bekleyen tutmayanlar da sayılır', () {
    // 5 belge: 1 kaydedildi, 1 tutmayan onay bekliyordu, 3. belgede kota doldu (3., 4., 5. + bekleyen = 4)
    final t = BatchUploadTally(5)..addSaved(7);
    t.stop('Kota doldu', isNetworkError: false, remaining: 3 + 1);
    expect(t.accounted, 5);
    expect(t.isStopped, isTrue);
    expect(t.stopIsNetworkError, isFalse);
    expect(t.summaryLines().last, 'Kota doldu: 4 belge kaydedilmedi.');
  });

  test('bağlantı sorunu kota dolu gibi gösterilmez', () {
    final t = BatchUploadTally(2);
    t.stop('İnternet yok', isNetworkError: true, remaining: 2);
    expect(t.stopIsNetworkError, isTrue);
    expect(t.summaryLines(), contains('Bağlantı sorunu: 2 belge kaydedilmedi.'));
    expect(t.accounted, 2);
  });
}
