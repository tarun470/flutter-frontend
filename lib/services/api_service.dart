import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/secure_storage.dart';
import '../utils/constants.dart';

class ApiService {
  static final SecureStorageService _storage = SecureStorageService();

  /// -------------------------
  /// LOGIN
  /// -------------------------
  static Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    final url = Uri.parse('${Constants.apiUrl}/auth/login');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String?;
        final user = data['user'];
        final userId = user?['id'] ?? user?['_id'];

        if (token != null && userId != null) {
          await _storage.saveToken(token);
          await _storage.saveUserId(userId);

          return {
            'token': token,
            'userId': userId,
            'username': user?['username'] ?? '',
            'nickname': user?['nickname'] ?? user?['username'] ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      print('Login exception: $e');
      return null;
    }
  }

  /// -------------------------
  /// REGISTER
  /// -------------------------
  static Future<Map<String, dynamic>?> register(String username, String password, {String? nickname}) async {
    final url = Uri.parse('${Constants.apiUrl}/auth/register');
    final body = {'username': username, 'password': password};
    if (nickname != null) body['nickname'] = nickname;

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = data['user'];
        final userId = user?['_id'] ?? user?['id'];

        return {
          'userId': userId,
          'username': user?['username'] ?? '',
          'nickname': user?['nickname'] ?? user?['username'] ?? '',
          'message': data['message'] ?? 'Registered successfully',
        };
      }
      return null;
    } catch (e) {
      print('Register exception: $e');
      return null;
    }
  }

  /// -------------------------
  /// LOGOUT
  /// -------------------------
  static Future<void> logout() async => await _storage.clearAll();

  /// -------------------------
  /// GETTERS
  /// -------------------------
  static Future<String?> getToken() async => await _storage.getToken();
  static Future<String?> getUserId() async => await _storage.getUserId();

  /// -------------------------
  /// FETCH MESSAGES
  /// -------------------------
  static Future<List<dynamic>> fetchMessages(String roomId, String token) async {
    final url = Uri.parse('${Constants.apiUrl}/messages?room=$roomId');
    final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      return List<dynamic>.from(jsonDecode(res.body));
    }
    return [];
  }

  /// -------------------------
  /// UPLOAD FILE / IMAGE
  /// -------------------------
  static Future<Map<String, dynamic>?> uploadFile(String path, String fieldName, {String? token, String? filename}) async {
    final uri = Uri.parse('${Constants.apiUrl}/upload');
    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath(fieldName, path, filename: filename));

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print('Upload failed: ${res.statusCode} ${res.body}');
        return null;
      }
    } catch (e) {
      print('Upload exception: $e');
      return null;
    }
  }
}
