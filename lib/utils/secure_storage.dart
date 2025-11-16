import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const _jwtKey = 'JWT_TOKEN';
  static const _userIdKey = 'USER_ID';
  static const _usernameKey = 'USERNAME';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _jwtKey, value: token);
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _jwtKey);
    } catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _jwtKey);
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }

  Future<void> saveUserId(String id) async {
    try {
      await _storage.write(key: _userIdKey, value: id);
    } catch (e) {
      debugPrint('Error saving userId: $e');
    }
  }

  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _userIdKey);
    } catch (e) {
      debugPrint('Error reading userId: $e');
      return null;
    }
  }

  Future<void> deleteUserId() async {
    try {
      await _storage.delete(key: _userIdKey);
    } catch (e) {
      debugPrint('Error deleting userId: $e');
    }
  }

  Future<void> saveUsername(String username) async {
    try {
      await _storage.write(key: _usernameKey, value: username);
    } catch (e) {
      debugPrint('Error saving username: $e');
    }
  }

  Future<String?> getUsername() async {
    try {
      return await _storage.read(key: _usernameKey);
    } catch (e) {
      debugPrint('Error reading username: $e');
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Error clearing storage: $e');
    }
  }
}
