import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showStatusChange(String title, String body) async {
    if (kIsWeb || !_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'status_channel',
      'Status Laporan',
      channelDescription: 'Notifikasi perubahan status laporan',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails);
    await _plugin.show(DateTime.now().millisecond, title, body, notifDetails);
  }
}
