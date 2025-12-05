import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html; // Only used on Web
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
  MessageCallback? onMessageEdited;
  MessageCallback? onMessageDeleted;
  MessageCallback? onMessageDelivered;
  MessageCallback? onMessageSeen;

  TypingCallback? onTyping;
  OnlineUsersCallback? onOnlineUsers;

  GenericCallback? onReactionUpdated;
  GenericCallback? onRoomList;
  GenericCallback? onLastSeenUpdated;

  // ----------------------------------------------------------------------
  // CONNECT
  // ----------------------------------------------------------------------
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
          .setReconnectionDelay(500)
          .enableForceNew()
          .setAuth({"token": token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        print("🟢 Connected: ${_socket!.id}");
        _initializeListeners();
        onConnect?.call();
      })
      ..onDisconnect((_) {
        print("🔴 Disconnected");
        onDisconnect?.call();
      })
      ..onConnectError((e) => print("❌ Connect error: $e"))
      ..onError((e) => print("❌ Socket error: $e"));
  }

  // ----------------------------------------------------------------------
  // INTERNAL LISTENERS
  // ----------------------------------------------------------------------
  void _initializeListeners() {
    void parse(dynamic data, void Function(Map<String, dynamic>) handler) {
      try {
        if (data is Map) {
          handler(Map<String, dynamic>.from(data));
        } else if (data is String) {
          handler(jsonDecode(data));
        }
      } catch (e) {
        print("❌ Invalid socket data format: $e\nData: $data");
      }
    }

    // -------------------------------
    // RECEIVE MESSAGE
    // -------------------------------
    _listen("receiveMessage", (m) {
      try {
        final msg = Message.fromJson(m);
        onMessage?.call(msg);
      } catch (e) {
        print("❌ Message parse failed: $e");
      }
    });

    // -------------------------------
    // TYPING
    // -------------------------------
    _listen("typing", (m) {
      onTyping?.call(
        m["userId"]?.toString() ?? "",
        m["isTyping"] == true,
        m["username"],
      );
    });

    // -------------------------------
    // ONLINE USERS
    // -------------------------------
    _listen("onlineUsers", (m) {
      final count = int.tryParse(m["count"].toString()) ?? 0;
      final map = Map<String, dynamic>.from(m["users"] ?? {});
      onOnlineUsers?.call(count, map);
    });

    // -------------------------------
    // MESSAGE EDIT
    // -------------------------------
    _listen("messageEdited", (m) {
      onMessageEdited?.call(Message.fromJson(m));
    });

    // -------------------------------
    // MESSAGE DELETE
    // -------------------------------
    _listen("messageDeleted", (m) {
      onMessageDeleted?.call(Message.fromJson(m));
    });

    // -------------------------------
    // MESSAGE DELIVERED
    // -------------------------------
    _listen("messageDelivered", (m) {
      final updated = Message(
        id: m["messageId"] ?? m["_id"] ?? "",
        senderId: "",
        senderName: "",
        roomId: m["roomId"] ?? "",
        content: "",
        type: "text",
        timestamp: DateTime.now(),
        isDelivered: true,
        isSeen: false,
        deliveredTo: List<String>.from(m["deliveredTo"] ?? []),
        reactions: {},
      );
      onMessageDelivered?.call(updated);
    });

    // -------------------------------
    // MESSAGE SEEN
    // -------------------------------
    _listen("messageSeen", (m) {
      final updated = Message(
        id: m["messageId"] ?? m["_id"] ?? "",
        senderId: "",
        senderName: "",
        roomId: m["roomId"] ?? "",
        content: "",
        type: "text",
        timestamp: DateTime.now(),
        isDelivered: true,
        isSeen: true,
        seenBy: List<String>.from(m["seenBy"] ?? []),
        reactions: {},
      );
      onMessageSeen?.call(updated);
    });

    // -------------------------------
    // OTHER EVENTS
    // -------------------------------
    _listen("reactionUpdated", (m) => onReactionUpdated?.call(m));
    _listen("roomsList", (m) => onRoomList?.call(m));
    _listen("lastSeen", (m) => onLastSeenUpdated?.call(m));
  }

  // Helper : attach listener with automatic cleanup
  void _listen(String event, Function(Map<String, dynamic>) handler) {
    _socket!..off(event);
    _socket!.on(event, (d) => _safeCallback(d, handler));
  }

  void _safeCallback(dynamic raw, Function(Map<String, dynamic>) handler) {
    try {
      if (raw is Map) {
        handler(Map<String, dynamic>.from(raw));
      } else if (raw is String) {
        handler(jsonDecode(raw));
      }
    } catch (_) {
      print("⚠️ Failed to decode event: $raw");
    }
  }

  // ----------------------------------------------------------------------
  // MESSAGE & FILE SENDING
  // ----------------------------------------------------------------------
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
      "tempId": tempId,
      "senderName": senderName,
      "replyTo": replyTo,
    });
  }

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
    _socket!.emit("addReaction", {"messageId": id, "emoji": emoji});
  }

  // ----------------------------------------------------------------------
  // FILE SENDING (Mobile + Web)
  // ----------------------------------------------------------------------
  void sendFile(
    String fileUrl,
    String fileName, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) {
    if (!isConnected) return;
    _socket!.emit("sendMessage", {
      "content": fileUrl,
      "fileName": fileName,
      "fileUrl": fileUrl,
      "type": "file",
      "roomId": roomId,
      "tempId": tempId,
      "senderName": senderName,
      "replyTo": replyTo,
    });
  }

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

  // ----------------------------------------------------------------------
  // ROOM / TYPING EVENTS
  // ----------------------------------------------------------------------
  void sendTyping(String room, String userId, String username, bool state) {
    if (!isConnected) return;
    _socket!.emit("typing",
        {"roomId": room, "userId": userId, "username": username, "isTyping": state});
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

  // ----------------------------------------------------------------------
  // DISCONNECT CLEANLY
  // ----------------------------------------------------------------------
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
