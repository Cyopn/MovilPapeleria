import 'dart:async';
import 'dart:convert';

import 'package:office_teschi/config/app_config.dart';
import 'package:office_teschi/services/app_messenger.dart';
import 'package:office_teschi/services/local_notifications_service.dart';
import 'package:office_teschi/session/user_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationsSseClient {
  NotificationsSseClient._();

  static final NotificationsSseClient instance = NotificationsSseClient._();

  http.Client? _client;
  StreamSubscription<String>? _lineSubscription;
  Timer? _reconnectTimer;

  bool _stopped = true;
  bool _connecting = false;
  int _reconnectAttempts = 0;
  DateTime? _lastErrorToastAt;

  int? _activeUserId;
  String? _activeToken;

  String _currentEvent = 'message';
  final List<String> _currentDataLines = <String>[];

  Future<void> ensureRunningForSession() async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      await stop();
      return;
    }

    final token = (UserSession.token ?? '').trim();
    final userId = UserSession.idUser ?? AppConfig.defaultUserId;

    final canConnect = token.isNotEmpty && userId > 1;
    if (!canConnect) {
      await stop();
      return;
    }

    if (!_stopped && _activeUserId == userId && _activeToken == token) {
      return;
    }

    await stop();
    _stopped = false;
    _activeUserId = userId;
    _activeToken = token;
    await LocalNotificationsService.instance.ensurePermission();
    _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _connecting = false;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _currentEvent = 'message';
    _currentDataLines.clear();

    await _lineSubscription?.cancel();
    _lineSubscription = null;

    _client?.close();
    _client = null;

    _activeUserId = null;
    _activeToken = null;
  }

  Uri? _buildStreamUri() {
    final base = AppConfig.apiUrl.trim();
    final userId = _activeUserId;
    if (base.isEmpty || userId == null) return null;

    final normalizedBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final path =
        '/notifications/stream/${Uri.encodeComponent(userId.toString())}';
    return Uri.parse('$normalizedBase$path');
  }

  void _connect() async {
    if (_stopped || _connecting) return;

    final uri = _buildStreamUri();
    final token = _activeToken;
    if (uri == null || token == null || token.isEmpty) return;

    _connecting = true;

    try {
      _client = http.Client();
      final request = http.Request('GET', uri)
        ..headers.addAll({
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Authorization': 'Bearer $token',
        });

      final response = await _client!.send(request);
      if (_stopped) return;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            'Estado ${response.statusCode} al abrir notificaciones');
      }

      _lineSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _onLine,
        onError: (Object error, StackTrace stackTrace) {
          _handleDisconnect(
              'Error de conexión de notificaciones. Reintentando...');
        },
        onDone: () {
          if (_stopped) return;
          _handleDisconnect(
              'Conexión de notificaciones cerrada. Reintentando...');
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect('Error de conexión de notificaciones. Reintentando...');
    } finally {
      _connecting = false;
    }
  }

  void _onLine(String line) {
    if (_stopped) return;

    if (line.isEmpty) {
      _dispatchCurrentEvent();
      return;
    }

    if (line.startsWith(':')) return;

    if (line.startsWith('event:')) {
      _currentEvent = line.substring(6).trim();
      return;
    }

    if (line.startsWith('data:')) {
      _currentDataLines.add(line.substring(5).trimLeft());
      return;
    }
  }

  void _dispatchCurrentEvent() {
    final event = _currentEvent;
    final data = _currentDataLines.join('\n');

    _currentEvent = 'message';
    _currentDataLines.clear();

    if (data.isEmpty) return;

    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        payload = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      payload = null;
    }

    if (event == 'connected') {
      _reconnectAttempts = 0;
      return;
    }

    if (event == 'init') {
      return;
    }

    if (event == 'notification') {
      final title =
          (payload?['title'] ?? payload?['type'] ?? 'Notificación').toString();
      final message = (payload?['message'] ?? data).toString();
      final durationMs =
          int.tryParse((payload?['duration'] ?? '').toString()) ?? 3300;

      LocalNotificationsService.instance.showNotification(
        title: title,
        body: message,
      );

      AppMessenger.showInfo(
        message,
        duration: Duration(milliseconds: durationMs.clamp(1000, 15000)),
      );
      return;
    }

    // Fallback for custom/unknown events with visible message.
    final fallbackMessage = payload?['message']?.toString();
    if (fallbackMessage != null && fallbackMessage.trim().isNotEmpty) {
      AppMessenger.showInfo(fallbackMessage);
    }
  }

  void _handleDisconnect(String message) {
    if (_stopped) return;

    _client?.close();
    _client = null;

    _lineSubscription?.cancel();
    _lineSubscription = null;

    final now = DateTime.now();
    final canShowToast = _lastErrorToastAt == null ||
        now.difference(_lastErrorToastAt!).inSeconds >= 8;
    if (canShowToast) {
      _lastErrorToastAt = now;
      AppMessenger.showError(message);
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_stopped) return;

    _reconnectAttempts = (_reconnectAttempts + 1).clamp(1, 6);
    final backoffMs = (500 * (1 << _reconnectAttempts)).clamp(500, 30000);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: backoffMs), () {
      if (_stopped) return;
      _connect();
    });
  }
}
