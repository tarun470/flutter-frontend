import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../utils/secure_storage.dart';
import '../utils/constants.dart';

/// -----------------------------------------------------------
/// USER MODEL
/// -----------------------------------------------------------
class UserModel {
  final String id;
  final String username;
  final String nickname;

  UserModel({
    required this.id,
    required this.username,
    required this.nickname,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      nickname: json['nickname'] ?? json['username'] ?? '',
    );
  }
}

/// -----------------------------------------------------------
/// MESSAGE MODEL (File + Text + Image Support)
/// -----------------------------------------------------------
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

/// -----------------------------------------------------------
/// API SERVICE — LOGIN, REGISTER, MESSAGES, FILE UPLOAD
/// -----------------------------------------------------------
class ApiService {
  static final SecureStorageService _storage = SecureStorageService();

  /// Common headers with optional token
  static Map<String, String> _headers({String? token}) {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  /// -----------------------------------------------------------
  /// LOGIN
  /// -----------------------------------------------------------
  static Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
    final url = Uri.parse("${Constants.apiUrl}/auth/login");

    try {
      final res = await http
          .post(
            url,
            headers: _headers(),
            body: jsonEncode({"username": username, "password": password}),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final token = body["token"] as String?;
        final userJson = body["user"];

        if (token == null || userJson == null) return null;

        final user = UserModel.fromJson(userJson);

        await _storage.saveToken(token);
        await _storage.saveUserId(user.id);
        await _storage.saveUsername(user.username);

        return {"token": token, "user": user};
      }

      return null;
    } on SocketException {
      print("❌ Login failed: No internet connection");
      return null;
    } catch (e) {
      print("❌ Login exception: $e");
      return null;
    }
  }

  /// -----------------------------------------------------------
  /// REGISTER
  /// -----------------------------------------------------------
  static Future<Map<String, dynamic>?> register(
    String username,
    String password, {
    String? nickname,
  }) async {
    final url = Uri.parse("${Constants.apiUrl}/auth/register");

    final body = {
      "username": username,
      "password": password,
      if (nickname != null) "nickname": nickname,
    };

    try {
      final res = await http
          .post(url, headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final json = jsonDecode(res.body);
        return {
          "user": UserModel.fromJson(json["user"]),
          "message": json["message"] ?? "Registered successfully"
        };
      }

      return null;
    } catch (e) {
      print("❌ Register exception: $e");
      return null;
    }
  }

  /// -----------------------------------------------------------
  /// FETCH MESSAGES
  /// -----------------------------------------------------------
  static Future<List<MessageModel>> fetchMessages(
      String roomId, String token) async {
    final url = Uri.parse("${Constants.apiUrl}/messages?room=$roomId");

    try {
      final res = await http
          .get(url, headers: _headers(token: token))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => MessageModel.fromJson(e)).toList();
      }

      return [];
    } catch (e) {
      print("❌ Fetch messages error: $e");
      return [];
    }
  }

  /// -----------------------------------------------------------
  /// FILE UPLOAD (Images, Documents, Audio, Video)
  /// -----------------------------------------------------------
  static Future<MessageModel?> uploadFile(
    String path,
    String fieldName, {
    String? token,
    String? filename,
  }) async {
    final url = Uri.parse("${Constants.apiUrl}/upload");

    final req = http.MultipartRequest("POST", url);

    // Add token
    if (token != null) req.headers["Authorization"] = "Bearer $token";

    // Add file
    req.files.add(await http.MultipartFile.fromPath(
      fieldName,
      path,
      filename: filename,
    ));

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final json = jsonDecode(res.body);

        return MessageModel(
          id: '',
          content: '',
          type: "file",
          fileUrl: json["url"],
          fileName: json["fileName"],
          roomId: "global",
          edited: false,
        );
      }

      print("❌ Upload failed: ${res.statusCode} ${res.body}");
      return null;
    } catch (e) {
      print("❌ File upload exception: $e");
      return null;
    }
  }

  /// -----------------------------------------------------------
  /// TOKEN HELPERS
  /// -----------------------------------------------------------
  static Future<String?> getToken() => _storage.getToken();
  static Future<String?> getUserId() => _storage.getUserId();
  static Future<void> logout() => _storage.clearAll();
}
