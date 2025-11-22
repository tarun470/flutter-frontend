import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/secure_storage.dart';
import '../utils/constants.dart';

class UserModel {
  final String id;
  final String username;
  final String nickname;

  UserModel({required this.id, required this.username, required this.nickname});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? json['username'] ?? '',
    );
  }
}

class MessageModel {
  final String id;
  final String content;
  final String type;
  final String? fileUrl;
  final String? fileName;
  final String roomId;
  final bool edited;

  MessageModel({
    required this.id,
    required this.content,
    required this.type,
    this.fileUrl,
    this.fileName,
    required this.roomId,
    required this.edited,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      roomId: json['roomId'] ?? 'global',
      edited: json['edited'] ?? false,
    );
  }
}

class ApiService {
  static final SecureStorageService _storage = SecureStorageService();

  static Map<String, String> _headers({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    final url = Uri.parse('${Constants.apiUrl}/auth/login');

    try {
      final res = await http
          .post(url, headers: _headers(), body: jsonEncode({'username': username, 'password': password}))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data['user']);
        final token = data['token'] as String?;
        if (token != null) {
          await _storage.saveToken(token);
          await _storage.saveUserId(user.id);
          return {'token': token, 'user': user};
        }
      }
      return null;
    } on SocketException {
      print('No internet connection.');
      return null;
    } on http.ClientException catch (e) {
      print('HTTP error: $e');
      return null;
    } catch (e) {
      print('Login exception: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> register(String username, String password, {String? nickname}) async {
    final url = Uri.parse('${Constants.apiUrl}/auth/register');
    final body = {'username': username, 'password': password};
    if (nickname != null) body['nickname'] = nickname;

    try {
      final res = await http
          .post(url, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data['user']);
        return {'user': user, 'message': data['message'] ?? 'Registered successfully'};
      }
      return null;
    } catch (e) {
      print('Register exception: $e');
      return null;
    }
  }

  static Future<void> logout() async => await _storage.clearAll();

  static Future<String?> getToken() async => await _storage.getToken();
  static Future<String?> getUserId() async => await _storage.getUserId();

  static Future<List<MessageModel>> fetchMessages(String roomId, String token) async {
    final url = Uri.parse('${Constants.apiUrl}/messages?room=$roomId');

    try {
      final res = await http.get(url, headers: _headers(token: token)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return data.map((json) => MessageModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Fetch messages exception: $e');
      return [];
    }
  }

  static Future<MessageModel?> uploadFile(String path, String fieldName, {String? token, String? filename}) async {
    final uri = Uri.parse('${Constants.apiUrl}/upload');
    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath(fieldName, path, filename: filename));

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return MessageModel(
          id: '',
          content: '',
          type: 'file',
          fileUrl: data['url'],
          fileName: data['fileName'],
          roomId: 'global',
          edited: false,
        );
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
