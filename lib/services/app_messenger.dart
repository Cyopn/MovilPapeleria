import 'package:flutter/material.dart';

class AppMessenger {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showInfo(String message, {Duration? duration}) {
    _show(
      message,
      backgroundColor: const Color(0xFF2F5BC0),
      duration: duration ?? const Duration(milliseconds: 3300),
    );
  }

  static void showError(String message, {Duration? duration}) {
    _show(
      message,
      backgroundColor: const Color(0xFFC62828),
      duration: duration ?? const Duration(milliseconds: 4000),
    );
  }

  static void _show(
    String message, {
    required Color backgroundColor,
    required Duration duration,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null || message.trim().isEmpty) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
      ),
    );
  }
}
