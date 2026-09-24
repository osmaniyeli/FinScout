import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_service.dart';
import 'notification_service.dart';
import 'user_profile_service.dart';

/// Yönetici duyurularının Android bildirim kanalı (send-push ile aynı kimlik).
const String kAnnouncementsChannelId = 'announcements';

/// Uygulama arka plandayken / kapalıyken gelen push mesajı. Ayrı isolate'ta çalışır;
/// mesajı gelen kutusu dosyasına yazar, uygulama açılınca Bildirimler listesine aktarılır.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await _PushInbox.append(message);
}

/// Firebase Cloud Messaging: yönetici panelinden gönderilen duyurular.
///
/// google-services.json yoksa Firebase başlatılamaz; push sessizce kapalı kalır,
/// uygulamanın geri kalanı etkilenmez. Cihaz token'ı yalnız oturum açıkken
/// Supabase `devices` tablosuna (register_device RPC) yazılır; çıkışta silinir.
class PushService with WidgetsBindingObserver {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;
  bool _enabled = false;
  String? _registeredToken;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Firebase kurulu ve push çalışıyor mu.
  bool get isEnabled => _enabled;

  /// Açılışta bir kez (runApp sonrası, beklemeden). Hata uygulamayı etkilemez.
  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase başlatılamadı, push kapalı: $e');
      return;
    }
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _createChannel();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_saveToInbox);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _saveToInbox(initial);

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        unawaited(_register(token));
      });
      AccountService.instance.authChanges?.listen((state) {
        if (state.event == AuthChangeEvent.signedIn) {
          unawaited(_onSignedIn());
        }
      });

      WidgetsBinding.instance.addObserver(this);
      _enabled = true;
      await _drainInbox();
      if (AccountService.instance.isSignedIn) await syncToken();
    } catch (e) {
      debugPrint('Push başlatılamadı: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka planda gelen duyuruları uygulama öne gelince listeye aktar
    if (state == AppLifecycleState.resumed) unawaited(_drainInbox());
  }

  Future<void> _onSignedIn() async {
    // Android 13+ bildirim izni (mevcut hatırlatıcılarla aynı sistem izni)
    try {
      await NotificationService.instance.requestPermission();
    } catch (_) {}
    await syncToken();
  }

  /// Oturum açıksa güncel FCM token'ını sunucuya yazar.
  Future<void> syncToken() async {
    if (!_enabled || !AccountService.instance.isSignedIn) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    }
  }

  Future<void> _register(String token) async {
    final client = AccountService.instance.signedInClient;
    if (client == null) return;
    try {
      await client.rpc('register_device', params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      });
      _registeredToken = token;
    } catch (e) {
      debugPrint('Cihaz kaydı yapılamadı: $e');
    }
  }

  /// Çıkıştan ÖNCE çağrılır (oturum hâlâ açıkken): bu cihazın kaydını siler.
  /// Ağ yoksa çıkışı bekletmez; hesap silmede satır zaten cascade ile silinir.
  Future<void> unregisterDevice() async {
    if (!_enabled) return;
    final client = AccountService.instance.signedInClient;
    if (client == null) return;
    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await client
          .from('devices')
          .delete()
          .eq('fcm_token', token)
          .timeout(const Duration(seconds: 5));
      _registeredToken = null;
    } catch (e) {
      debugPrint('Cihaz kaydı silinemedi: $e');
    }
  }

  Future<void> _createChannel() async {
    // flutter_local_notifications eklentisini (kanal + ön plan gösterimi) hazırlar
    await NotificationService.instance.initialize();
    const channel = AndroidNotificationChannel(
      kAnnouncementsChannelId,
      'Duyurular',
      description: 'FinScout ekibinden duyurular',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Uygulama açıkken Android bildirimi kendisi göstermez: yerel bildirimle göster.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final item = _PushItem.fromMessage(message);
    if (item == null) return;
    try {
      await _local.show(
        id: NotificationService.stableId('push|${item.id}'),
        title: item.title,
        body: item.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kAnnouncementsChannelId,
            'Duyurular',
            channelDescription: 'FinScout ekibinden duyurular',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_finscout',
            color: Color(0xFF10B981),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Push bildirimi gösterilemedi: $e');
    }
    await _addToList(item);
  }

  Future<void> _saveToInbox(RemoteMessage message) async {
    final item = _PushItem.fromMessage(message);
    if (item != null) await _addToList(item);
  }

  Future<void> _drainInbox() async {
    for (final item in await _PushInbox.drain()) {
      await _addToList(item);
    }
  }

  Future<void> _addToList(_PushItem item) async {
    // Aynı duyuru (id) listede ikinci kez görünmez
    await UserProfileService.instance.addNotification(
      id: 'push_${item.id}',
      title: item.title,
      message: item.body,
    );
  }
}

class _PushItem {
  final String id;
  final String title;
  final String body;
  const _PushItem(this.id, this.title, this.body);

  static _PushItem? fromMessage(RemoteMessage m) {
    final title = m.notification?.title ?? m.data['title']?.toString() ?? '';
    final body = m.notification?.body ?? m.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return null;
    final id = m.data['id']?.toString() ??
        m.messageId ??
        '${title.hashCode}_${body.hashCode}';
    return _PushItem(id, title.isEmpty ? 'FinScout' : title, body);
  }

  Map<String, String> toJson() => {'id': id, 'title': title, 'body': body};
}

/// Arka plan isolate'ı ile ana uygulama arasında dosya tabanlı gelen kutusu.
class _PushInbox {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/push_inbox.json');
  }

  static Future<void> append(RemoteMessage message) async {
    final item = _PushItem.fromMessage(message);
    if (item == null) return;
    try {
      final file = await _file();
      final list = <dynamic>[];
      if (await file.exists()) {
        try {
          list.addAll(jsonDecode(await file.readAsString()) as List);
        } catch (_) {}
      }
      list.add(item.toJson());
      await file.writeAsString(jsonEncode(list), flush: true);
    } catch (_) {}
  }

  static Future<List<_PushItem>> drain() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      // Önce taşı, sonra oku: bu arada gelen mesaj yeni dosyaya yazılır, kaybolmaz
      final taken = await file.rename('${file.path}.reading');
      final raw = await taken.readAsString();
      await taken.delete();
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => _PushItem(
                m['id']?.toString() ?? '',
                m['title']?.toString() ?? 'FinScout',
                m['body']?.toString() ?? '',
              ))
          .where((i) => i.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
