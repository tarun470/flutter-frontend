import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);
typedef TypingCallback = void Function(String userId, bool isTyping, String? username);
typedef OnlineUsersCallback = void Function(int count, Map<String, dynamic> usersMap);
typedef GenericCallback = void Function(dynamic payload);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  // Callbacks
  MessageCallback? onMessage;
  TypingCallback? onTyping;
  OnlineUsersCallback? onOnlineUsers;
  MessageCallback? onMessageEdited;
  MessageCallback? onMessageDeleted;
  GenericCallback? onReactionUpdated;
  GenericCallback? onRoomList;
  GenericCallback? onLastSeenUpdated;

  // --------------------------------------
  // CONNECT
  // --------------------------------------
  void connect(
    String token, {
    String url = 'https://chat-backend-mnz7.onrender.com',
    void Function()? onConnect,
    void Function()? onDisconnect,
    void Function(dynamic)? onError,
  }) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(500)
          .setReconnectionAttempts(50)
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        print("🔥 SOCKET CONNECTED: ${_socket!.id}");
        _initializeListeners();
        onConnect?.call();
      })
      ..onDisconnect((_) {
        print("⚠️ Socket Disconnected");
        onDisconnect?.call();
      })
      ..onError((e) {
        print("❌ Socket Error: $e");
        onError?.call(e);
      })
      ..onConnectError((e) {
        print("❌ Connect Error: $e");
      });
  }

  // --------------------------------------
  // LISTENERS
  // --------------------------------------
  void _initializeListeners() {
    void safeMap(dynamic data, Function(Map<String, dynamic>) callback) {
      if (data == null) return;

      if (data is String) {
        try {
          callback(jsonDecode(data));
        } catch (_) {
          print("Invalid JSON: $data");
        }
      } else if (data is Map) {
        callback(data.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        print("Unknown data format from backend: $data");
      }
    }

    // ------------------------------
    // RECEIVE MESSAGE (room + broadcast)
    // ------------------------------
    _socket!.off("receiveMessage");
    _socket!.on("receiveMessage", (data) {
      safeMap(data, (map) => onMessage?.call(Message.fromJson(map)));
    });

    // ------------------------------
    // TYPING
    // ------------------------------
    _socket!.off("typing");
    _socket!.on("typing", (data) {
      safeMap(data, (map) {
        onTyping?.call(
          map['userId'] ?? '',
          map['isTyping'] ?? false,
          map['username'] ?? '',
        );
      });
    });

    // ------------------------------
    // ONLINE USERS
    // ------------------------------
    _socket!.off("onlineUsers");
    _socket!.on("onlineUsers", (data) {
      safeMap(data, (map) {
        onOnlineUsers?.call(
          map['count'] ?? 0,
          Map<String, dynamic>.from(map['users'] ?? {}),
        );
      });
    });

    // ------------------------------
    // MESSAGE UPDATES
    // ------------------------------
    void messageUpdateListener(String event, MessageCallback? callback) {
      _socket!.off(event);
      _socket!.on(event, (data) {
        safeMap(data, (map) => callback?.call(Message.fromJson(map)));
      });
    }

    messageUpdateListener("messageDelivered", onMessageEdited);
    messageUpdateListener("messageSeen", onMessageEdited);
    messageUpdateListener("messageEdited", onMessageEdited);
    messageUpdateListener("messageDeleted", onMessageDeleted);

    // ------------------------------
    // GENERIC EVENTS
    // ------------------------------
    _socket!.off("reactionUpdated");
    _socket!.on("reactionUpdated", (d) => onReactionUpdated?.call(d));

    _socket!.off("roomsList");
    _socket!.on("roomsList", (d) => onRoomList?.call(d));

    _socket!.off("lastSeen");
    _socket!.on("lastSeen", (d) => onLastSeenUpdated?.call(d));
  }

  // --------------------------------------
  // SEND TEXT MESSAGE
  // --------------------------------------
  void sendMessage(
    String content, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) {
    if (!isConnected) return;
    final payload = {
      "content": content,
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "replyTo": replyTo,
      "type": "text",
    };
    _socket!.emit("sendMessage", payload);
  }

  // --------------------------------------
  // SEND IMAGE
  // --------------------------------------
  void sendImageFile(
    html.File file, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) async {
    if (!isConnected) return;

    final reader = html.FileReader();
    reader.readAsDataUrl(file);

    reader.onLoadEnd.listen((_) {
      final dataUrl = reader.result as String;

      _socket!.emit("sendMessage", {
        "content": dataUrl,
        "roomId": roomId,
        "senderName": senderName,
        "tempId": tempId,
        "type": "image",
        "fileName": file.name,
        "replyTo": replyTo,
      });
    });
  }

  // --------------------------------------
  // SEND FILE
  // --------------------------------------
  void sendFileWeb(
    html.File file, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) async {
    if (!isConnected) return;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);

    reader.onLoadEnd.listen((_) {
      final bytes = reader.result as Uint8List;
      final base64Data = base64Encode(bytes);

      _socket!.emit("sendMessage", {
        "content": base64Data,
        "roomId": roomId,
        "senderName": senderName,
        "tempId": tempId,
        "type": "file",
        "fileName": file.name,
        "replyTo": replyTo,
      });
    });
  }

  // --------------------------------------
  // BROADCAST MESSAGE
  // --------------------------------------
  void broadcastMessage(String content, {required String senderName}) {
    if (!isConnected) return;
    _socket!.emit("broadcastMessage", {
      "content": content,
      "senderName": senderName,
    });
  }

  // --------------------------------------
  // TYPING
  // --------------------------------------
  void sendTyping(String roomId, String userId, String username, bool isTyping) {
    if (!isConnected) return;

    _socket!.emit("typing", {
      "roomId": roomId,
      "userId": userId,
      "username": username,
      "isTyping": isTyping,
    });
  }

  // --------------------------------------
  // ROOMS
  // --------------------------------------
  void joinRoom(String roomId) {
    if (!isConnected) return;
    _socket!.emit("joinRoom", {"roomId": roomId});
  }

  void leaveRoom(String roomId) {
    if (!isConnected) return;
    _socket!.emit("leaveRoom", {"roomId": roomId});
  }

  void requestRooms() {
    if (!isConnected) return;
    _socket!.emit("getRooms");
  }

  // --------------------------------------
  // DISCONNECT
  // --------------------------------------
  void disconnect() {
    if (_socket == null) return;

    _socket!.off("receiveMessage");
    _socket!.off("typing");
    _socket!.off("onlineUsers");
    _socket!.off("roomsList");
    _socket!.off("messageSeen");
    _socket!.off("messageDelivered");
    _socket!.off("messageEdited");
    _socket!.off("messageDeleted");
    _socket!.off("reactionUpdated");
    _socket!.off("lastSeen");

    _socket!.disconnect();
    _socket!.dispose();
    _socket = null;

    print("🔌 SOCKET CLEANLY DISCONNECTED");
  }

  bool get isConnected => _socket?.connected ?? false;
}
