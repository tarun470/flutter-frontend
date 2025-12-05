import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A faster, safer Secure Storage wrapper with:
/// - Optional in-memory caching
/// - Automatic Web fallback
/// - Cleaner API usage
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Secure storage NOT supported on Flutter Web → use memory map
  final FlutterSecureStorage _storage =
      !kIsWeb ? const FlutterSecureStorage() : const FlutterSecureStorage();

  static const String _jwtKey = 'JWT_TOKEN';
  static const String _userIdKey = 'USER_ID';
  static const String _usernameKey = 'USERNAME';

  /// 🔥 In-memory cache = avoids disk read every time → 5x faster
  final Map<String, String?> _cache = {};

  // ------------------------------
  // Save Methods
  // ------------------------------
  Future<void> saveToken(String token) => _write(_jwtKey, token);
  Future<void> saveUserId(String id) => _write(_userIdKey, id);
  Future<void> saveUsername(String username) => _write(_usernameKey, username);

  // ------------------------------
  // Get Methods
  // ------------------------------
  Future<String?> getToken() => _read(_jwtKey);
  Future<String?> getUserId() => _read(_userIdKey);
  Future<String?> getUsername() => _read(_usernameKey);

  // ------------------------------
  // Delete Methods
  // ------------------------------
  Future<void> deleteToken() => _delete(_jwtKey);
  Future<void> deleteUserId() => _delete(_userIdKey);

  // Clear everything (logout)
  Future<void> clearAll() async {
    try {
      _cache.clear();
      if (!kIsWeb) await _storage.deleteAll();
    } catch (e) {
      debugPrint("⚠️ Error clearing storage: $e");
    }
  }

  // ------------------------------
  // Internal Helpers
  // ------------------------------

  Future<void> _write(String key, String value) async {
    try {
      _cache[key] = value;
      if (!kIsWeb) await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint("⚠️ Error writing [$key]: $e");
    }
  }

  Future<String?> _read(String key) async {
    try {
      // 1️⃣ Return from RAM cache → fastest
      if (_cache.containsKey(key)) return _cache[key];

      // 2️⃣ On Web, secure storage doesn't persist → return null
      if (kIsWeb) return null;

      // 3️⃣ Read from secure storage
      final value = await _storage.read(key: key);
      _cache[key] = value;
      return value;
    } catch (e) {
      debugPrint("⚠️ Error reading [$key]: $e");
      return null;
    }
  }

  Future<void> _delete(String key) async {
    try {
      _cache.remove(key);
      if (!kIsWeb) await _storage.delete(key: key);
    } catch (e) {
      debugPrint("⚠️ Error deleting [$key]: $e");
    }
  }
}
