import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 🔔 Kleiner Helfer rund um lokale Benachrichtigungen (Download
/// abgeschlossen) -- kapselt Initialisierung + Laufzeit-Berechtigung
/// (Android 13+) an einer Stelle, damit main.dart/download_tab.dart
/// schlank bleiben.
class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Muss einmal beim App-Start aufgerufen werden.
  static Future<void> init() async {
    if (_initialized) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Fragt auf Android 13+ die Benachrichtigungs-Berechtigung zur
  /// Laufzeit ab (no-op auf älteren Android-Versionen).
  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Zeigt eine einfache "Download abgeschlossen"-Benachrichtigung.
  static Future<void> showDownloadCompleteNotification(String title) async {
    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      null,
      details,
    );
  }
}
