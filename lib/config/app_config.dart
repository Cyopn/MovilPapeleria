import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String _defaultApiUrl = '';
  static const String _defaultBearerToken = '';
  static const int _defaultUserId = 1;

  static String get apiUrl {
    final value = dotenv.env['API_URL']?.trim();
    if (value == null || value.isEmpty) {
      return _defaultApiUrl;
    }
    return value;
  }

  static String get bearerToken {
    final value = dotenv.env['BEARER_TOKEN']?.trim();
    if (value == null || value.isEmpty) {
      return _defaultBearerToken;
    }
    return value;
  }

  static int get defaultUserId {
    final value = dotenv.env['DEFAULT_USER_ID']?.trim();
    if (value == null || value.isEmpty) {
      return _defaultUserId;
    }
    return int.tryParse(value) ?? _defaultUserId;
  }
}
