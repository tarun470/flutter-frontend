import 'dart:convert';
import 'dart:html' as html; // NOTE: Web builds only
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

  // ---------------- CALLBACKS ----------------
  MessageCallback? onMessage;
  MessageCallback? onMessageEdited;
  MessageCallback? onMessageDeleted;
  MessageCallback? onMessageDelivered;
  MessageCallback? onMessageSeen;

  TypingCallback? onTyping;
  OnlineUsersCallback? onOnlineUsers;
  GenericCallback? onReactionUpdated;
  GenericCallback? onRoomList;
  GenericCallback? onLastSeenUpdated;

  // ---------------- CONNECT ----------------
  void connect(
    String token, {
    String url = "https://chat-backend-mnz7.onrender.com",
    void Function()? onConnect,
    void Function()? onDisconnect,
  }) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(["websocket"])
          .enableReconnection()
          .setReconnectionAttempts(40)
          .enableForceNew()
          .setAuth({"token": token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        print("🟢 Socket connected → ID: ${_socket!.id}");
        _initializeListeners();
        onConnect?.call();
      })
      ..onDisconnect((_) {
        print("🔴 Socket disconnected");
        onDisconnect?.call();
      })
      ..onConnectError((e) => print("❌ Connect error: $e"))
      ..onError((e) => print("❌ Socket error: $e"));
  }

  // ---------------- INTERNAL LISTENERS ----------------
  void _initializeListeners() {
    _listen("receiveMessage", (m) {
      try {
        onMessage?.call(Message.fromJson(m));
      } catch (e) {
        print("❌ Message parse failed: $e");
      }
    });

    _listen("typing", (m) {
      onTyping?.call(
        m["userId"]?.toString() ?? "",
        m["isTyping"] == true,
        m["username"],
      );
    });

    _listen("onlineUsers", (m) {
      onOnlineUsers?.call(
        int.tryParse(m["count"].toString()) ?? 0,
        Map<String, dynamic>.from(m["users"] ?? {}),
      );
    });

    _listen("messageEdited", (m) {
      onMessageEdited?.call(Message.fromJson(m));
    });

    _listen("messageDeleted", (m) {
      onMessageDeleted?.call(Message.fromJson(m));
    });

    _listen("messageDelivered", (m) {
      final updated = Message(
        id: m["messageId"],
        senderId: m["senderId"] ?? "",
        senderName: m["senderName"] ?? "",
        roomId: m["roomId"] ?? "",
        content: "",
        type: "text",
        timestamp: DateTime.now(),
        isDelivered: true,
        isSeen: false,
        deliveredTo: List<String>.from(m["deliveredTo"] ?? []),
        seenBy: List<String>.from(m["seenBy"] ?? []),
        reactions: {},
      );
      onMessageDelivered?.call(updated);
    });

    _listen("messageSeen", (m) {
      final updated = Message(
        id: m["messageId"],
        senderId: m["senderId"] ?? "",
        senderName: m["senderName"] ?? "",
        roomId: m["roomId"] ?? "",
        content: "",
        type: "text",
        timestamp: DateTime.now(),
        isDelivered: true,
        isSeen: true,
        deliveredTo: List<String>.from(m["deliveredTo"] ?? []),
        seenBy: List<String>.from(m["seenBy"] ?? []),
        reactions: {},
      );
      onMessageSeen?.call(updated);
    });

    _listen("reactionUpdated", (m) => onReactionUpdated?.call(m));
    _listen("roomsList", (m) => onRoomList?.call(m));
    _listen("lastSeen", (m) => onLastSeenUpdated?.call(m));
  }

  void _listen(String event, Function(Map<String, dynamic>) handler) {
    _socket!..off(event);
    _socket!.on(event, (d) => _safeDecode(d, handler));
  }

  void _safeDecode(dynamic raw, Function(Map<String, dynamic>) handler) {
    try {
      if (raw is Map) {
        handler(Map<String, dynamic>.from(raw));
      } else if (raw is String) {
        handler(jsonDecode(raw));
      }
    } catch (e) {
      print("⚠️ Failed to decode event: $raw");
    }
  }

  // ---------------- SEND TEXT MESSAGE ----------------
  void sendMessage(
    String content, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) {
    if (!isConnected) return;

    _socket!.emit("sendMessage", {
      "content": content,
      "type": "text",
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "replyTo": replyTo,
    });
  }

  // ---------------- SEND FILE MESSAGE ----------------
  void sendFile(
    String url,
    String name, {
    required String roomId,
    required String senderName,
    String? replyTo,
    String? tempId,
  }) {
    if (!isConnected) return;

    _socket!.emit("sendMessage", {
      "type": "file",
      "content": url,
      "fileUrl": url,
      "fileName": name,
      "roomId": roomId,
      "senderName": senderName,
      "replyTo": replyTo,
      "tempId": tempId,
    });
  }

  // ---------------- SEND IMAGE (WEB ONLY) ----------------
  void sendImageWeb(html.File file,
      {required String roomId, required String senderName}) {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);

    reader.onLoadEnd.listen((_) {
      _socket!.emit("sendMessage", {
        "type": "image",
        "content": reader.result,
        "fileName": file.name,
        "roomId": roomId,
        "senderName": senderName,
      });
    });
  }

  // ---------------- EDIT / DELETE / REACTIONS ----------------
  void editMessage(String id, String newText) {
    if (!isConnected) return;
    _socket!.emit("editMessage", {"messageId": id, "content": newText});
  }

  void deleteMessage(String id, {bool forEveryone = false}) {
    if (!isConnected) return;
    _socket!.emit("deleteMessage", {
      "messageId": id,
      "forEveryone": forEveryone,
    });
  }

  void addReaction(String id, String emoji) {
    if (!isConnected) return;
    _socket!.emit("addReaction", {
      "messageId": id,
      "emoji": emoji,
    });
  }

  // ---------------- TYPING & ROOMS ----------------
  void sendTyping(String roomId, String uid, String uname, bool typing) {
    if (!isConnected) return;
    _socket!.emit("typing", {
      "roomId": roomId,
      "userId": uid,
      "username": uname,
      "isTyping": typing,
    });
  }

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

  // ---------------- DISCONNECT ----------------
  void disconnect() {
    if (_socket == null) return;

    _socket!
      ..off("receiveMessage")
      ..off("typing")
      ..off("onlineUsers")
      ..off("messageEdited")
      ..off("messageDeleted")
      ..off("messageDelivered")
      ..off("messageSeen")
      ..off("reactionUpdated")
      ..off("roomsList")
      ..off("lastSeen")
      ..disconnect()
      ..dispose();

    _socket = null;
    print("🔌 Socket disconnected cleanly");
  }

  bool get isConnected => _socket?.connected ?? false;
}
