import 'dart:convert';
import 'dart:io';

import 'package:office_teschi/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _authResponseKey = 'auth_response';

  static File? profileImage;
  static String? username;
  static String? names;
  static String? lastnames;
  static String? email;
  static String? phone;
  static String? role;
  static String? avatar;
  static String? password;
  static int? idUser;
  static String? token;
  static Map<String, dynamic>? user;
  static Map<String, dynamic>? authResponse;
  static int guestCount = 0;

  static Map<String, dynamic>? _asStringKeyMap(dynamic source) {
    if (source is Map) {
      return source.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static void _applyUserFields(Map<String, dynamic>? source) {
    if (source == null) return;

    user = source;
    idUser = int.tryParse((source['id_user'] ?? '').toString());
    username = source['username']?.toString();
    names = source['names']?.toString();
    lastnames = source['lastnames']?.toString();
    email = source['email']?.toString();
    phone = source['phone']?.toString();
    role = source['role']?.toString();
    avatar = source['avatar']?.toString();
    password = source['password']?.toString();
  }

  static Future<void> saveAuthData({
    required String token,
    required Map<String, dynamic> user,
    required Map<String, dynamic> authResponse,
  }) async {
    final normalizedUser = _asStringKeyMap(user) ?? <String, dynamic>{};
    final normalizedAuthResponse =
        _asStringKeyMap(authResponse) ?? <String, dynamic>{};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(normalizedUser));
    await prefs.setString(_authResponseKey, jsonEncode(normalizedAuthResponse));

    UserSession.token = token;
    UserSession.authResponse = normalizedAuthResponse;
    _applyUserFields(normalizedUser);
  }

  static Future<void> loadAuthData() async {
    final fallbackUserId = AppConfig.defaultUserId;
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    final savedUser = prefs.getString(_userKey);
    final savedAuthResponse = prefs.getString(_authResponseKey);

    token = savedToken;

    if (savedUser != null) {
      final decodedUser = _asStringKeyMap(jsonDecode(savedUser));
      _applyUserFields(decodedUser);
    }

    if (savedAuthResponse != null) {
      final decodedAuthResponse =
          _asStringKeyMap(jsonDecode(savedAuthResponse));
      if (decodedAuthResponse != null) {
        authResponse = decodedAuthResponse;
        final responseUser = _asStringKeyMap(decodedAuthResponse['user']);

        if (responseUser != null) {
          final mergedUser = <String, dynamic>{...responseUser, ...?user};
          _applyUserFields(mergedUser);
        }
      }
    }

    // If there is no active session, default to guest user id from env.
    if (token == null || user == null) {
      idUser = fallbackUserId;
    }
  }

  static Future<void> applyUserUpdateResponse(
      Map<String, dynamic> response) async {
    final normalizedResponse = _asStringKeyMap(response) ?? <String, dynamic>{};
    final responseUser = _asStringKeyMap(normalizedResponse['user']) ??
        _asStringKeyMap(normalizedResponse);

    if (responseUser == null) return;

    final mergedUser = <String, dynamic>{...?(user), ...responseUser};
    _applyUserFields(mergedUser);

    final responseToken = normalizedResponse['token']?.toString();
    if (responseToken != null && responseToken.trim().isNotEmpty) {
      token = responseToken;
    }

    final mergedAuthResponse = <String, dynamic>{
      ...?(authResponse),
      ...normalizedResponse,
      'user': mergedUser,
      if (token != null) 'token': token,
    };

    authResponse = mergedAuthResponse;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(mergedUser));
    await prefs.setString(_authResponseKey, jsonEncode(mergedAuthResponse));
    if (token != null && token!.isNotEmpty) {
      await prefs.setString(_tokenKey, token!);
    }
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_authResponseKey);

    token = null;
    user = null;
    authResponse = null;
    idUser = AppConfig.defaultUserId;
    username = null;
    names = null;
    lastnames = null;
    email = null;
    phone = null;
    role = null;
    avatar = null;
    password = null;
    profileImage = null;
  }
}
