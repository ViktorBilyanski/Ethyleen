import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/sensor_reading.dart';
import 'firebase_service.dart';
import 'settings_service.dart';

class AlertService {
  final FirebaseService _firebase = FirebaseService();
  final SettingsService _settings = SettingsService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  FreshnessLevel? _lastAlertedLevel;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create notification channel (Android 8+)
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
      'spoilage_alerts',
      'Spoilage Alerts',
      description: 'Alerts when food spoilage is detected',
      importance: Importance.high,
    ));

    // Request notification permission (Android 13+)
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Start listening to readings and fire local notifications
  void startListening() {
    _firebase.latestReadingStream.listen((reading) {
      if (reading == null) return;

      // Only notify when freshness changes to warning or spoiled
      // Don't re-notify for the same level
      if (reading.freshness == FreshnessLevel.fresh) {
        _lastAlertedLevel = null;
        return;
      }

      if (reading.freshness == _lastAlertedLevel) return;
      _lastAlertedLevel = reading.freshness;

      if (!_settings.notificationsEnabled || _settings.alertsMuted) return;
      _showAlert(reading);
    });
  }

  void _showAlert(SensorReading reading) {
    final isWarning = reading.freshness == FreshnessLevel.warning;

    final title = isWarning ? 'Food spoilage warning' : 'Food is spoiled!';

    final causes = <String>[];
    if (reading.mq135 >= 4) causes.add('protein breakdown (meat/dairy)');
    if (reading.mq3 >= 0.5) causes.add('fermentation (fruits/bread)');
    if (reading.mq9 >= 1.5) causes.add('anaerobic decay (sealed food)');

    final body = isWarning
        ? 'Early signs: ${causes.join(", ")}. Use affected food soon.'
        : 'Detected: ${causes.join(", ")}. Check your fridge immediately.';

    _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'spoilage_alerts',
          'Spoilage Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
