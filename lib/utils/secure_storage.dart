import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _jwtKey = 'JWT_TOKEN';
  static const _userIdKey = 'USER_ID';

  /// Save JWT token securely
  Future<void> saveToken(String token) async {
    try {
      if (kIsWeb) {
        // Web fallback: store in memory or localStorage if needed
        // For simplicity, using flutter_secure_storage which works with web
        await _storage.write(key: _jwtKey, value: token);
      } else {
        await _storage.write(key: _jwtKey, value: token);
      }
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  /// Retrieve JWT token
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _jwtKey);
    } catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }

  /// Delete JWT token
  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _jwtKey);
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }

  /// Save User ID securely
  Future<void> saveUserId(String id) async {
    try {
      await _storage.write(key: _userIdKey, value: id);
    } catch (e) {
      debugPrint('Error saving userId: $e');
    }
  }

  /// Retrieve User ID
  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _userIdKey);
    } catch (e) {
      debugPrint('Error reading userId: $e');
      return null;
    }
  }

  /// Delete User ID
  Future<void> deleteUserId() async {
    try {
      await _storage.delete(key: _userIdKey);
    } catch (e) {
      debugPrint('Error deleting userId: $e');
    }
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing storage: $e');
    }
  }
}
