import 'dart:convert';
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

  // -----------------------------
  // CONNECT
  // -----------------------------
  void connect(String token,
      {String url = 'https://chat-backend-mnz7.onrender.com',
      void Function()? onConnect,
      void Function()? onDisconnect,
      void Function(dynamic)? onError}) {
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

  void _initializeListeners() {
    // receive new message
    _socket!.off("receiveMessage");
    _socket!.on("receiveMessage", (data) {
      final json = data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
      final msg = Message.fromJson(json);
      onMessage?.call(msg);
    });

    // typing indicator
    _socket!.off("typing");
    _socket!.on("typing", (data) {
      final map = data is String ? jsonDecode(data) : data;
      onTyping?.call(map['userId'] ?? '', map['isTyping'] ?? false, map['username'] ?? '');
    });

    // online users: count + optional user map {userId: {username, lastSeen, isOnline}}
    _socket!.off("onlineUsers");
    _socket!.on("onlineUsers", (data) {
      final map = data is String ? jsonDecode(data) : data;
      final count = map['count'] ?? (map is int ? map : 0);
      final users = map['users'] ?? {};
      onOnlineUsers?.call(count, users);
    });

    // message delivered
    _socket!.off("messageDelivered");
    _socket!.on("messageDelivered", (data) {
      final json = data is String ? jsonDecode(data) : data;
      onMessageEdited?.call(Message.fromJson(json)); // re-use edited callback to update UI
    });

    // message seen
    _socket!.off("messageSeen");
    _socket!.on("messageSeen", (data) {
      final json = data is String ? jsonDecode(data) : data;
      onMessageEdited?.call(Message.fromJson(json));
    });

    // message edited
    _socket!.off("messageEdited");
    _socket!.on("messageEdited", (data) {
      final json = data is String ? jsonDecode(data) : data;
      onMessageEdited?.call(Message.fromJson(json));
    });

    // message deleted
    _socket!.off("messageDeleted");
    _socket!.on("messageDeleted", (data) {
      final json = data is String ? jsonDecode(data) : data;
      onMessageDeleted?.call(Message.fromJson(json));
    });

    // reaction updated
    _socket!.off("reactionUpdated");
    _socket!.on("reactionUpdated", (data) {
      onReactionUpdated?.call(data);
    });

    // rooms list
    _socket!.off("roomsList");
    _socket!.on("roomsList", (data) => onRoomList?.call(data));

    // last seen updates
    _socket!.off("lastSeen");
    _socket!.on("lastSeen", (data) => onLastSeenUpdated?.call(data));
  }

  // -----------------------------
  // SEND MESSAGE / IMAGE / FILE
  // -----------------------------
  void sendMessage(String content, {required String roomId, required String senderName, String? tempId, String? replyTo}) {
    if (!isConnected) return;
    final payload = {
      "content": content,
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "replyTo": replyTo,
      "type": "text"
    };
    _socket!.emit("sendMessage", payload);
  }

  void sendImage(String imageUrl, {required String roomId, required String senderName, String? tempId, String? replyTo}) {
    if (!isConnected) return;
    _socket!.emit("sendMessage", {
      "content": imageUrl,
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "type": "image",
      "replyTo": replyTo
    });
  }

  void sendFile(String fileUrl, String filename, {required String roomId, required String senderName, String? tempId, String? replyTo}) {
    if (!isConnected) return;
    _socket!.emit("sendMessage", {
      "content": fileUrl,
      "fileName": filename,
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "type": "file",
      "replyTo": replyTo
    });
  }

  // -----------------------------
  // TYPING
  // -----------------------------
  void sendTyping(String roomId, String userId, String username, bool isTyping) {
    if (!isConnected) return;
    _socket!.emit("typing", {"roomId": roomId, "userId": userId, "username": username, "isTyping": isTyping});
  }

  // -----------------------------
  // READ / DELIVERED
  // -----------------------------
  void markDelivered(String messageId, String roomId) {
    if (!isConnected) return;
    _socket!.emit("delivered", {"messageId": messageId, "roomId": roomId});
  }

  void markSeen(String messageId, String roomId) {
    if (!isConnected) return;
    _socket!.emit("seen", {"messageId": messageId, "roomId": roomId});
  }

  // -----------------------------
  // EDIT / DELETE / REACTIONS
  // -----------------------------
  void editMessage(String messageId, String newText) {
    if (!isConnected) return;
    _socket!.emit("editMessage", {"messageId": messageId, "content": newText});
  }

  void deleteMessage(String messageId, {bool forEveryone = false}) {
    if (!isConnected) return;
    _socket!.emit("deleteMessage", {"messageId": messageId, "forEveryone": forEveryone});
  }

  void addReaction(String messageId, String emoji) {
    if (!isConnected) return;
    _socket!.emit("addReaction", {"messageId": messageId, "emoji": emoji});
  }

  void removeReaction(String messageId, String emoji) {
    if (!isConnected) return;
    _socket!.emit("removeReaction", {"messageId": messageId, "emoji": emoji});
  }

  // -----------------------------
  // ROOMS
  // -----------------------------
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

  // -----------------------------
  // DISCONNECT
  // -----------------------------
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
