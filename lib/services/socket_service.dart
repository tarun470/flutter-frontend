import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/message.dart';

typedef MessageCallback = void Function(Message message);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  MessageCallback? _onMessageCallback;

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
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        print('✅ Socket connected: ${_socket!.id}');
        onConnect?.call();
        if (_onMessageCallback != null) _listenMessageInternal(_onMessageCallback!);
      })
      ..onDisconnect((_) => onDisconnect?.call())
      ..onError((data) => onError?.call(data))
      ..onConnectError((data) => onError?.call(data));
  }

  void listenMessage(MessageCallback callback) {
    _onMessageCallback = callback;
    if (_socket != null && _socket!.connected) _listenMessageInternal(callback);
  }

  void _listenMessageInternal(MessageCallback callback) {
    _socket!.off('receiveMessage');
    _socket!.on('receiveMessage', (data) {
      try {
        final map = data is String ? jsonDecode(data) : Map<String, dynamic>.from(data);
        final msg = Message.fromJson(map);
        if (msg.id.isNotEmpty) callback(msg);
      } catch (e) {
        print('⚠️ Message parse error: $e');
      }
    });
  }

  void sendMessage(String content) {
    if (_socket == null || !_socket!.connected) return;
    if (content.trim().isEmpty) return;
    _socket!.emit('sendMessage', {'content': content.trim()});
    print('📤 Sending message: {content: $content}');
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.off('receiveMessage');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _onMessageCallback = null;
      print('🔌 Socket disconnected & disposed');
    }
  }

  bool get isConnected => _socket?.connected ?? false;
}




