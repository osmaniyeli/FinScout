import 'package:flutter/foundation.dart';

/// Finansal veri değiştiğinde (ekstre, manuel kayıt, silme, kategori, geri yükleme, sıfırlama) artan sayaç.
/// Ana sayfa ve Analiz bunu dinleyip kendini yeniden yükler; sekmeler IndexedStack içinde canlı kaldığı
/// için initState'te bir kez yüklemek yetmez.
class DataChanges {
  DataChanges._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notify() => revision.value++;
}
