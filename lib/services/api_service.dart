import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/secure_storage.dart';
import '../utils/constants.dart';

class ApiService {
  static final SecureStorageService _storage = SecureStorageService();

  /// LOGIN
  static Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
    final url = Uri.parse('${Constants.apiUrl}/auth/login');

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      print('Login response status: ${res.statusCode}');
      print('Login response body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String?;
        final user = data['user'];
        final userId = user?['id'] ?? user?['_id'];

        if (token != null && userId != null) {
          // Save token & userId securely
          await _storage.saveToken(token);
          await _storage.saveUserId(userId);
          return {
            'token': token,
            'userId': userId,
            'username': user?['username'] ?? '',
          };
        } else {
          print('Login failed: Missing token or userId in response.');
          return null;
        }
      } else {
        print('Login failed: ${res.body}');
        return null;
      }
    } catch (e) {
      print('Login exception: $e');
      return null;
    }
  }

  /// REGISTER
  static Future<Map<String, dynamic>?> register(
      String username, String password) async {
    final url = Uri.parse('${Constants.apiUrl}/auth/register');

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      print('Register response status: ${res.statusCode}');
      print('Register response body: ${res.body}');

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final user = data['user'];
        final userId = user?['_id'] ?? user?['id'];

        return {
          'userId': userId,
          'username': user?['username'] ?? '',
          'message': data['message'] ?? 'Registered successfully',
        };
      } else if (res.statusCode == 400) {
        print('Register failed: User already exists.');
        return null;
      } else {
        print('Register failed: ${res.body}');
        return null;
      }
    } catch (e) {
      print('Register exception: $e');
      return null;
    }
  }

  /// LOGOUT
  static Future<void> logout() async {
    await _storage.clearAll();
  }

  /// GETTERS
  static Future<String?> getToken() async => await _storage.getToken();
  static Future<String?> getUserId() async => await _storage.getUserId();
}
