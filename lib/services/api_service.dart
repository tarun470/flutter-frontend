import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../utils/secure_storage.dart';
import '../utils/constants.dart';

/// ===============================================
/// USER MODEL (Updated for new backend format)
/// ===============================================
class UserModel {
  final String id;
  final String username;
  final String nickname;

  UserModel({
    required this.id,
    required this.username,
    required this.nickname,
  });

  factory UserModel.fromLogin(Map<String, dynamic> json) {
    return UserModel(
      id: json["userId"] ?? "",
      username: json["username"] ?? "",
      nickname: json["nickname"] ?? json["username"] ?? "",
    );
  }

  factory UserModel.fromRegister(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"] ?? "",
      username: json["username"] ?? "",
      nickname: json["nickname"] ?? "",
    );
  }
}

/// ===============================================
/// MESSAGE MODEL
/// ===============================================
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
      id: json["_id"] ?? "",
      content: json["content"] ?? "",
      type: json["type"] ?? "text",
      fileUrl: json["fileUrl"],
      fileName: json["fileName"],
      roomId: json["roomId"] ?? "global",
      edited: json["edited"] ?? false,
    );
  }
}

/// ===============================================
/// API SERVICE — Login, Register, Messages, Upload
/// ===============================================
class ApiService {
  static final SecureStorageService _storage = SecureStorageService();

  static Map<String, String> _headers({String? token}) {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ============================================================
  // LOGIN (FULLY FIXED FOR NEW BACKEND)
  // ============================================================
  static Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
    final url = Uri.parse("${Constants.apiUrl}/auth/login");

    try {
      final res = await http.post(
        url,
        headers: _headers(),
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      print("LOGIN STATUS: ${res.statusCode}");
      print("LOGIN BODY: ${res.body}");

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);

      final token = data["token"];
      if (token == null) return null;

      final user = UserModel.fromLogin(data);

      // Save securely
      await _storage.saveToken(token);
      await _storage.saveUserId(user.id);
      await _storage.saveUsername(user.username);

      return {
        "token": token,
        "user": user,
      };
    } catch (e) {
      print("❌ LOGIN ERROR: $e");
      return null;
    }
  }

  // ============================================================
  // REGISTER (UPDATED)
  // ============================================================
  static Future<Map<String, dynamic>?> register(
    String username,
    String password,
    String nickname,
  ) async {
    final url = Uri.parse("${Constants.apiUrl}/auth/register");

    try {
      final res = await http.post(
        url,
        headers: _headers(),
        body: jsonEncode({
          "username": username,
          "password": password,
          "nickname": nickname,
        }),
      );

      print("REGISTER STATUS: ${res.statusCode}");
      print("REGISTER BODY: ${res.body}");

      if (res.statusCode != 201) return null;

      final body = jsonDecode(res.body);
      final user = UserModel.fromRegister(body["user"]);

      return {
        "user": user,
        "message": body["message"] ?? "Registered successfully",
      };
    } catch (e) {
      print("❌ REGISTER ERROR: $e");
      return null;
    }
  }

  // ============================================================
  // FETCH MESSAGES
  // ============================================================
  static Future<List<MessageModel>> fetchMessages(
      String roomId, String token) async {
    final url = Uri.parse("${Constants.apiUrl}/messages?room=$roomId");

    try {
      final res =
          await http.get(url, headers: _headers(token: token));

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => MessageModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("❌ FETCH MESSAGES ERROR: $e");
      return [];
    }
  }

  // ============================================================
  // FILE UPLOAD
  // ============================================================
  static Future<MessageModel?> uploadFile(
    String path,
    String fieldName, {
    String? token,
    String? filename,
  }) async {
    final url = Uri.parse("${Constants.apiUrl}/upload");

    final req = http.MultipartRequest("POST", url);

    if (token != null) {
      req.headers["Authorization"] = "Bearer $token";
    }

    req.files.add(await http.MultipartFile.fromPath(
      fieldName,
      path,
      filename: filename,
    ));

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final json = jsonDecode(res.body);

        return MessageModel(
          id: "",
          content: "",
          type: "file",
          fileUrl: json["url"],
          fileName: json["fileName"],
          roomId: "global",
          edited: false,
        );
      }

      print("❌ UPLOAD FAILED: ${res.body}");
      return null;
    } catch (e) {
      print("❌ FILE UPLOAD ERROR: $e");
      return null;
    }
  }

  // ============================================================
  // TOKEN HELPERS
  // ============================================================
  static Future<String?> getToken() => _storage.getToken();
  static Future<String?> getUserId() => _storage.getUserId();
  static Future<void> logout() => _storage.clearAll();
}
