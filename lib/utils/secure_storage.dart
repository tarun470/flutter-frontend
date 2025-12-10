import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:html' as html; // Only used on Web

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // -----------------------------------------------------------
  // Storage for Mobile, Web uses LocalStorage
  // -----------------------------------------------------------
  final FlutterSecureStorage? _storage =
      kIsWeb ? null : const FlutterSecureStorage();

  // -----------------------------------------------------------
  // Keys
  // -----------------------------------------------------------
  static const String _jwtKey = "JWT_TOKEN";
  static const String _userIdKey = "USER_ID";
  static const String _usernameKey = "USERNAME";

  // -----------------------------------------------------------
  // RAM Cache (Fast access)
  // -----------------------------------------------------------
  final Map<String, String?> _cache = {};

  // Enable LocalStorage for Web
  final bool enableWebLocalStorage = true;

  // -----------------------------------------------------------
  // SAVE
  // -----------------------------------------------------------
  Future<void> saveToken(String token) => _write(_jwtKey, token);
  Future<void> saveUserId(String id) => _write(_userIdKey, id);
  Future<void> saveUsername(String name) => _write(_usernameKey, name);

  // -----------------------------------------------------------
  // READ
  // -----------------------------------------------------------
  Future<String?> getToken() => _read(_jwtKey);
  Future<String?> getUserId() => _read(_userIdKey);
  Future<String?> getUsername() => _read(_usernameKey);

  // -----------------------------------------------------------
  // DELETE
  // -----------------------------------------------------------
  Future<void> deleteToken() => _delete(_jwtKey);
  Future<void> deleteUserId() => _delete(_userIdKey);
  Future<void> deleteUsername() => _delete(_usernameKey);

  // -----------------------------------------------------------
  // LOGOUT (Clears all credentials)
  // -----------------------------------------------------------
  Future<void> logout() async {
    await deleteToken();
    await deleteUserId();
    await deleteUsername();
  }

  // -----------------------------------------------------------
  // FULL CLEAR (Deletes everything including cache)
  // -----------------------------------------------------------
  Future<void> clearAll() async {
    _cache.clear();

    if (kIsWeb && enableWebLocalStorage) {
      html.window.localStorage.remove(_jwtKey);
      html.window.localStorage.remove(_userIdKey);
      html.window.localStorage.remove(_usernameKey);
      return;
    }

    if (_storage != null) {
      await _storage!.deleteAll();
    }
  }

  // -----------------------------------------------------------
  // CHECK LOGIN
  // -----------------------------------------------------------
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // -----------------------------------------------------------
  // INTERNAL WRITE
  // -----------------------------------------------------------
  Future<void> _write(String key, String value) async {
    _cache[key] = value; // store in RAM

    if (kIsWeb && enableWebLocalStorage) {
      html.window.localStorage[key] = value;
      return;
    }

    if (_storage != null) {
      try {
        await _storage!.write(key: key, value: value);
      } catch (e) {
        debugPrint("⚠️ Storage write error [$key]: $e");
      }
    }
  }

  // -----------------------------------------------------------
  // INTERNAL READ
  // -----------------------------------------------------------
  Future<String?> _read(String key) async {
    // 1️⃣ RAM first (fast)
    if (_cache.containsKey(key)) return _cache[key];

    // 2️⃣ Web LocalStorage
    if (kIsWeb && enableWebLocalStorage) {
      final value = html.window.localStorage[key];
      _cache[key] = value;
      return value;
    }

    // 3️⃣ Mobile SecureStorage
    if (_storage != null) {
      try {
        final value = await _storage!.read(key: key);
        _cache[key] = value;
        return value;
      } catch (e) {
        debugPrint("⚠️ Storage read error [$key]: $e");
      }
    }

    return null;
  }

  // -----------------------------------------------------------
  // INTERNAL DELETE
  // -----------------------------------------------------------
  Future<void> _delete(String key) async {
    _cache.remove(key);

    if (kIsWeb && enableWebLocalStorage) {
      html.window.localStorage.remove(key);
      return;
    }

    if (_storage != null) {
      try {
        await _storage!.delete(key: key);
      } catch (e) {
        debugPrint("⚠️ Storage delete error [$key]: $e");
      }
    }
  }
}
