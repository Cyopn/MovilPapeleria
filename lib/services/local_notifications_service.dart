import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  static const String _channelId = 'orders_notifications';
  static const String _channelName = 'Notificaciones de pedidos';
  static const String _channelDescription =
      'Alertas de pedidos y actualizaciones de estado';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _pluginAvailable = true;

  Future<void> init() async {
    if (_initialized || !_pluginAvailable) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(settings);
    } on MissingPluginException {
      _pluginAvailable = false;
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> ensurePermission() async {
    if (!_pluginAvailable) return;

    if (!_initialized) {
      await init();
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_pluginAvailable) return;

    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
    );

    final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
    try {
      await _plugin.show(id, title, body, details);
    } on MissingPluginException {
      _pluginAvailable = false;
    }
  }
}
