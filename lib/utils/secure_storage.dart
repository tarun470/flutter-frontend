import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:html' as html; // Only used on web

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // -----------------------------------------------------------
  // Secure Storage for Mobile
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
  // RAM cache (Fast!)
  // -----------------------------------------------------------
  final Map<String, String?> _cache = {};

  // Enable LocalStorage for Web
  final bool enableWebLocalStorage = true;

  // -----------------------------------------------------------
  // SAVE VALUES
  // -----------------------------------------------------------
  Future<void> saveToken(String token) => _write(_jwtKey, token);
  Future<void> saveUserId(String id) => _write(_userIdKey, id);
  Future<void> saveUsername(String name) => _write(_usernameKey, name);

  // -----------------------------------------------------------
  // READ VALUES
  // -----------------------------------------------------------
  Future<String?> getToken() => _read(_jwtKey);
  Future<String?> getUserId() => _read(_userIdKey);
  Future<String?> getUsername() => _read(_usernameKey);

  // -----------------------------------------------------------
  // DELETE VALUES
  // -----------------------------------------------------------
  Future<void> deleteToken() => _delete(_jwtKey);
  Future<void> deleteUserId() => _delete(_userIdKey);
  Future<void> deleteUsername() => _delete(_usernameKey);

  // -----------------------------------------------------------
  // LOGOUT (Clear all)
  // -----------------------------------------------------------
  Future<void> logout() async {
    await deleteToken();
    await deleteUserId();
    await deleteUsername();
  }

  // OPTIONAL: Full wipe method
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
  // CHECK LOGIN STATUS
  // -----------------------------------------------------------
  Future<bool> isLoggedIn() async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  // -----------------------------------------------------------
  // INTERNAL WRITE
  // -----------------------------------------------------------
  Future<void> _write(String key, String value) async {
    _cache[key] = value;

    if (kIsWeb && enableWebLocalStorage) {
      html.window.localStorage[key] = value;
      return;
    }

    if (_storage != null) {
      try {
        await _storage!.write(key: key, value: value);
      } catch (e) {
        debugPrint("⚠️ Error writing [$key]: $e");
      }
    }
  }

  // -----------------------------------------------------------
  // INTERNAL READ
  // -----------------------------------------------------------
  Future<String?> _read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];

    if (kIsWeb && enableWebLocalStorage) {
      final v = html.window.localStorage[key];
      _cache[key] = v;
      return v;
    }

    if (_storage != null) {
      try {
        final v = await _storage!.read(key: key);
        _cache[key] = v;
        return v;
      } catch (e) {
        debugPrint("⚠️ Error reading [$key]: $e");
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
        debugPrint("⚠️ Error deleting [$key]: $e");
      }
    }
  }
}
