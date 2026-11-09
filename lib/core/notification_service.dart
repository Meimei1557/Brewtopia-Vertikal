import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    _ready = true;
  }

  /// Minta izin notifikasi (Android 13+). Dipanggil setelah login, bukan saat start.
  Future<bool> requestPermission() async {
    await init();
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return (await impl?.requestNotificationsPermission()) ?? true;
  }

  Future<void> show(int id, String title, String body) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'cafe_updates',
        'Kabar Kafe',
        channelDescription: 'Pendapatan kafe saat kamu pergi dan pengingat bermain',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
