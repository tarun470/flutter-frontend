import 'dart:convert';
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

  // ===============================
  // CONNECT SOCKET
  // ===============================
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
          .enableForceNew()
          .enableReconnection()
          .setReconnectionAttempts(50)
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

  // ===============================
  // INTERNAL LISTENERS
  // ===============================
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
        m["userId"] ?? "",
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

  // ===============================
  // SEND TEXT MESSAGE
  // ===============================
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

  // ===============================
  // SEND FILE
  // ===============================
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

  // ===============================
  // TYPING
  // ===============================
  void sendTyping(String roomId, String uid, String uname, bool typing) {
    if (!isConnected) return;

    _socket!.emit("typing", {
      "roomId": roomId,
      "userId": uid,
      "username": uname,
      "isTyping": typing,
    });
  }

  // ===============================
  // JOIN ROOM
  // ===============================
  void joinRoom(String roomId) {
    if (!isConnected) return;
    _socket!.emit("joinRoom", {"roomId": roomId});
  }

  // ===============================
  // DISCONNECT (WEB SAFE) ✔ FIXED
  // ===============================
  void disconnect() {
    if (_socket == null) return;

    print("🔌 Cleaning socket before logout...");

    try {
      // SAFELY disable reconnection without causing web build error
      final opts = _socket!.io.options;
      if (opts != null && opts is Map<String, dynamic>) {
        opts["reconnection"] = false;
      }
    } catch (e) {
      print("⚠️ Unable to modify reconnection flag: $e");
    }

    try {
      _socket!.offAny();
    } catch (e) {
      print("⚠️ Error clearing listeners: $e");
    }

    try {
      _socket!
        ..disconnect()
        ..close()
        ..dispose();
    } catch (e) {
      print("⚠️ Error during disconnect: $e");
    }

    _socket = null;
    print("🛑 Socket fully terminated.");
  }

  bool get isConnected => _socket?.connected ?? false;
}
