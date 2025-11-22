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
  MessageCallback? onMessageDelivered;
  MessageCallback? onMessageSeen;
  GenericCallback? onReactionUpdated;
  GenericCallback? onRoomList;
  GenericCallback? onLastSeenUpdated;

  // -------------------------
  // CONNECT
  // -------------------------
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
        print("⚠️ SOCKET DISCONNECTED");
        onDisconnect?.call();
      })
      ..onError((e) {
        print("❌ SOCKET ERROR: $e");
        onError?.call(e);
      })
      ..onConnectError((e) {
        print("❌ CONNECT ERROR: $e");
      });
  }

  // -------------------------
  // LISTENERS
  // -------------------------
  void _initializeListeners() {
    void safeMap(dynamic data, Function(Map<String, dynamic>) callback) {
      if (data == null) return;

      if (data is String) {
        try {
          callback(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          print("Invalid JSON: $data");
        }
      } else if (data is Map) {
        callback(data.map((k, v) => MapEntry(k.toString(), v)));
      } else {
        print("Unknown data format: $data");
      }
    }

    // -------------------------
    // RECEIVE MESSAGE
    // -------------------------
    _socket!..off("receiveMessage");
    _socket!.on("receiveMessage", (data) {
      safeMap(data, (map) {
        try {
          onMessage?.call(Message.fromJson(Map<String, dynamic>.from(map)));
        } catch (e) {
          print("receiveMessage parse error: $e");
        }
      });
    });

    // -------------------------
    // TYPING
    // -------------------------
    _socket!..off("typing");
    _socket!.on("typing", (data) {
      safeMap(data, (map) {
        onTyping?.call(
          map['userId']?.toString() ?? '',
          map['isTyping'] == true,
          map['username']?.toString(),
        );
      });
    });

    // -------------------------
    // ONLINE USERS
    // -------------------------
    _socket!..off("onlineUsers");
    _socket!.on("onlineUsers", (data) {
      safeMap(data, (map) {
        final count = (map['count'] is int)
            ? map['count'] as int
            : int.tryParse(map['count']?.toString() ?? '0') ?? 0;
        final users = Map<String, dynamic>.from(map['users'] ?? {});
        onOnlineUsers?.call(count, users);
      });
    });

    // -------------------------
    // MESSAGE UPDATES
    // -------------------------
    void messageUpdateListener(String event, MessageCallback? callback) {
      _socket!..off(event);
      _socket!.on(event, (data) {
        safeMap(data, (map) {
          try {
            callback?.call(Message.fromJson(Map<String, dynamic>.from(map)));
          } catch (e) {
            print("$event parse error (expected full message): $e");
          }
        });
      });
    }

    messageUpdateListener("messageEdited", onMessageEdited);
    messageUpdateListener("messageDeleted", onMessageDeleted);

    // -------------------------
    // MESSAGE DELIVERED / SEEN
    // -------------------------
    _socket!..off("messageDelivered");
    _socket!.on("messageDelivered", (data) {
      safeMap(data, (map) {
        final mid = (map['messageId'] ?? map['_id'] ?? '').toString();
        final delivered = (map['deliveredTo'] is List)
            ? List<String>.from((map['deliveredTo'] as List).map((e) => e.toString()))
            : <String>[];

        final m = Message(
          id: mid,
          senderId: '',
          senderName: '',
          roomId: map['roomId']?.toString() ?? '',
          content: '',
          type: 'text',
          timestamp: DateTime.now(),
          isDelivered: delivered.isNotEmpty,
          isSeen: false,
          reactions: {},
          replyToMessageId: null,
          deliveredTo: delivered,
          seenBy: [],
        );

        onMessageDelivered?.call(m);
      });
    });

    _socket!..off("messageSeen");
    _socket!.on("messageSeen", (data) {
      safeMap(data, (map) {
        final mid = (map['messageId'] ?? map['_id'] ?? '').toString();
        final seen = (map['seenBy'] is List)
            ? List<String>.from((map['seenBy'] as List).map((e) => e.toString()))
            : <String>[];

        final m = Message(
          id: mid,
          senderId: '',
          senderName: '',
          roomId: map['roomId']?.toString() ?? '',
          content: '',
          type: 'text',
          timestamp: DateTime.now(),
          isDelivered: true,
          isSeen: seen.isNotEmpty,
          reactions: {},
          replyToMessageId: null,
          deliveredTo: [],
          seenBy: seen,
        );

        onMessageSeen?.call(m);
      });
    });

    // -------------------------
    // OTHER EVENTS
    // -------------------------
    _socket!..off("reactionUpdated");
    _socket!.on("reactionUpdated", (d) => onReactionUpdated?.call(d));

    _socket!..off("roomsList");
    _socket!.on("roomsList", (d) => onRoomList?.call(d));

    _socket!..off("lastSeen");
    _socket!.on("lastSeen", (d) => onLastSeenUpdated?.call(d));
  }

  // -------------------------
  // MESSAGES
  // -------------------------
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
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "replyTo": replyTo,
      "type": "text",
    });
  }

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

  // -------------------------
  // SEND FILES (Web)
  // -------------------------
  void sendImageFile(
    html.File file, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) {
    if (!isConnected) return;
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((_) {
      _socket!.emit("sendMessage", {
        "content": reader.result,
        "roomId": roomId,
        "senderName": senderName,
        "tempId": tempId,
        "type": "image",
        "fileName": file.name,
        "replyTo": replyTo,
      });
    });
  }

  void sendFileWeb(
    html.File file, {
    required String roomId,
    required String senderName,
    String? tempId,
    String? replyTo,
  }) {
    if (!isConnected) return;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      final bytes = reader.result as Uint8List;
      _socket!.emit("sendMessage", {
        "content": base64Encode(bytes),
        "roomId": roomId,
        "senderName": senderName,
        "tempId": tempId,
        "type": "file",
        "fileName": file.name,
        "replyTo": replyTo,
      });
    });
  }

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
      "fileUrl": fileUrl,
      "fileName": fileName,
      "roomId": roomId,
      "senderName": senderName,
      "tempId": tempId,
      "type": "file",
      "replyTo": replyTo,
    });
  }

  // -------------------------
  // BROADCAST
  // -------------------------
  void broadcastMessage(String content, {required String senderName}) {
    if (!isConnected) return;
    _socket!.emit("broadcastMessage", {"content": content, "senderName": senderName});
  }

  void sendTyping(String roomId, String userId, String username, bool isTyping) {
    if (!isConnected) return;
    _socket!.emit("typing", {
      "roomId": roomId,
      "userId": userId,
      "username": username,
      "isTyping": isTyping,
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

  void disconnect() {
    if (_socket == null) return;
    _socket!
      ..off("receiveMessage")
      ..off("typing")
      ..off("onlineUsers")
      ..off("roomsList")
      ..off("messageSeen")
      ..off("messageDelivered")
      ..off("messageEdited")
      ..off("messageDeleted")
      ..off("reactionUpdated")
      ..off("lastSeen")
      ..disconnect()
      ..dispose();
    _socket = null;
    print("🔌 SOCKET CLEANLY DISCONNECTED");
  }

  bool get isConnected => _socket?.connected ?? false;
}
