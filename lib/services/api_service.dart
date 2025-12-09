import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../utils/secure_storage.dart';
import '../utils/constants.dart';

/// ===============================================================
/// USER MODEL
/// ===============================================================
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
      id: json["id"] ?? json["_id"] ?? "",
      username: json["username"] ?? "",
      nickname: json["nickname"] ?? json["username"] ?? "",
    );
  }

  factory UserModel.fromLogin(Map<String, dynamic> json) {
    return UserModel.fromJson(json["user"] ?? {});
  }

  factory UserModel.fromRegister(Map<String, dynamic> json) {
    return UserModel.fromJson(json);
  }
}

/// ===============================================================
/// MESSAGE MODEL
/// ===============================================================
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
      roomId: json["roomId"] ?? "general",
      edited: json["edited"] ?? false,
    );
  }
}

/// ===============================================================
/// API SERVICE
/// ===============================================================
class ApiService {
  static final SecureStorageService _storage = SecureStorageService();

  /// Base URL
  static String get base => Constants.apiUrl;

  /// ===============================================================
  /// Headers
  /// ===============================================================
  static Map<String, String> _headers({String? token}) {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  /// ===============================================================
  /// LOGIN
  /// POST /api/auth/login
  /// ===============================================================
  static Future<Map<String, dynamic>?> loginUser(
      String username, String password) async {
    final url = Uri.parse("$base/auth/login");

    try {
      final res = await http.post(
        url,
        headers: _headers(),
        body: jsonEncode({
          "username": username.trim(),
          "password": password.trim(),
        }),
      );

      if (res.statusCode != 200) {
        print("❌ LOGIN FAILED: ${res.body}");
        return null;
      }

      final data = jsonDecode(res.body);

      final token = data["token"];
      if (token == null) return null;

      final user = UserModel.fromLogin(data);

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

  /// ===============================================================
  /// REGISTER
  /// POST /api/auth/register
  /// ===============================================================
  static Future<Map<String, dynamic>?> register(
      String username, String password,
      {required String nickname}) async {
    final url = Uri.parse("$base/auth/register");

    try {
      final res = await http.post(
        url,
        headers: _headers(),
        body: jsonEncode({
          "username": username.trim(),
          "password": password.trim(),
          "nickname": nickname.trim(),
        }),
      );

      if (res.statusCode != 201) {
        print("❌ REGISTER FAILED: ${res.body}");
        return null;
      }

      final body = jsonDecode(res.body);
      final user = UserModel.fromRegister(body["user"]);

      return {
        "user": user,
        "message": body["message"] ?? "Registration successful",
      };
    } catch (e) {
      print("❌ REGISTER ERROR: $e");
      return null;
    }
  }

  /// ===============================================================
  /// FETCH MESSAGES
  /// GET /api/messages?room=general
  /// ===============================================================
  static Future<List<MessageModel>> fetchMessages(
      String roomId, String token) async {
    final url = Uri.parse("$base/messages?room=$roomId");

    try {
      final res = await http.get(url, headers: _headers(token: token));

      if (res.statusCode != 200) {
        print("❌ FETCH MESSAGES FAILED: ${res.body}");
        return [];
      }

      final data = jsonDecode(res.body);
      final list = data["messages"] ?? [];

      return list.map<MessageModel>((e) => MessageModel.fromJson(e)).toList();
    } catch (e) {
      print("❌ FETCH MESSAGES ERROR: $e");
      return [];
    }
  }

  /// ===============================================================
  /// FILE UPLOAD
  /// POST /api/upload
  /// ===============================================================
  static Future<MessageModel?> uploadFile(
    String path,
    String fieldName, {
    String? token,
    String? filename,
  }) async {
    final url = Uri.parse("$base/upload");

    final req = http.MultipartRequest("POST", url);

    if (token != null) {
      req.headers["Authorization"] = "Bearer $token";
    }

    req.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        path,
        filename: filename ?? path.split("/").last,
      ),
    );

    try {
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode != 200 && res.statusCode != 201) {
        print("❌ FILE UPLOAD FAILED: ${res.body}");
        return null;
      }

      final json = jsonDecode(res.body);

      return MessageModel(
        id: json["_id"] ?? "",
        content: "",
        type: "file",
        fileUrl: json["url"] ?? json["fileUrl"],
        fileName: json["fileName"],
        roomId: "general",
        edited: false,
      );
    } catch (e) {
      print("❌ FILE UPLOAD ERROR: $e");
      return null;
    }
  }

  /// ===============================================================
  /// LOGOUT — FIXED FOR WEB ✔
  /// ===============================================================
  static Future<void> logout() async {
    await _storage.clearAll(); // FIXED!
  }

  /// ===============================================================
  /// GET TOKEN HELPERS
  /// ===============================================================
  static Future<String?> getToken() => _storage.getToken();
  static Future<String?> getUserId() => _storage.getUserId();
}
