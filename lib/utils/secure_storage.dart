import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage wrapper with:
/// ✔ Mobile secure storage
/// ✔ Web-friendly in-memory fallback
/// ✔ Fast RAM cache for all platforms
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  /// Secure Storage for Mobile (disabled for Web)
  final FlutterSecureStorage? _storage =
      kIsWeb ? null : const FlutterSecureStorage();

  // Keys
  static const String _jwtKey = "JWT_TOKEN";
  static const String _userIdKey = "USER_ID";
  static const String _usernameKey = "USERNAME";

  /// Fast in-memory cache (RAM)
  final Map<String, String?> _cache = {};

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------
  Future<void> saveToken(String token) => _write(_jwtKey, token);
  Future<void> saveUserId(String id) => _write(_userIdKey, id);
  Future<void> saveUsername(String name) => _write(_usernameKey, name);

  // ------------------------------------------------------------
  // READ
  // ------------------------------------------------------------
  Future<String?> getToken() => _read(_jwtKey);
  Future<String?> getUserId() => _read(_userIdKey);
  Future<String?> getUsername() => _read(_usernameKey);

  // ------------------------------------------------------------
  // DELETE / CLEAR
  // ------------------------------------------------------------
  Future<void> deleteToken() => _delete(_jwtKey);
  Future<void> deleteUserId() => _delete(_userIdKey);

  Future<void> clearAll() async {
    _cache.clear();

    // No secure storage on web
    if (kIsWeb || _storage == null) return;

    try {
      await _storage!.deleteAll();
    } catch (e) {
      debugPrint("⚠️ clearAll() error: $e");
    }
  }

  // ------------------------------------------------------------
  // INTERNAL STORAGE LOGIC
  // ------------------------------------------------------------

  Future<void> _write(String key, String value) async {
    // Always update RAM cache
    _cache[key] = value;

    // Save to secure storage only on mobile
    if (!kIsWeb && _storage != null) {
      try {
        await _storage!.write(key: key, value: value);
      } catch (e) {
        debugPrint("⚠️ Error writing [$key]: $e");
      }
    }
  }

  Future<String?> _read(String key) async {
    // 1) RAM cache (fastest)
    if (_cache.containsKey(key)) return _cache[key];

    // 2) On web → return null (persistent storage not allowed)
    if (kIsWeb || _storage == null) return null;

    // 3) Mobile secure storage
    try {
      final value = await _storage!.read(key: key);
      _cache[key] = value; // cache it
      return value;
    } catch (e) {
      debugPrint("⚠️ Error reading [$key]: $e");
      return null;
    }
  }

  Future<void> _delete(String key) async {
    _cache.remove(key);

    if (!kIsWeb && _storage != null) {
      try {
        await _storage!.delete(key: key);
      } catch (e) {
        debugPrint("⚠️ Error deleting [$key]: $e");
      }
    }
  }
}
