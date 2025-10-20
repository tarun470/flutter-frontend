import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef MessageCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

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
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!
      ..onConnect((_) => onConnect?.call())
      ..onDisconnect((_) => onDisconnect?.call())
      ..onError((data) => onError?.call(data))
      ..onConnectError((data) => onError?.call(data))
      ..onReconnect((_) => print('🔄 Socket reconnected'))
      ..onReconnectAttempt((_) => print('⏳ Socket reconnecting...'));
  }

  void listenMessage(MessageCallback callback) {
    _socket?.off('receiveMessage');
    _socket?.on('receiveMessage', (data) {
      final msg = data is String
          ? jsonDecode(data)
          : Map<String, dynamic>.from(data);
      callback(msg);
    });
  }

  /// Send message and wait for server confirmation
  Future<Map<String, dynamic>?> sendMessage(String content) async {
    if (_socket == null || !_socket!.connected) return null;

    final completer = Completer<Map<String, dynamic>>();

    void handler(dynamic data) {
      try {
        final msg = data is String
            ? jsonDecode(data)
            : Map<String, dynamic>.from(data);

        // Only complete if content matches
        if (msg['content'] == content) {
          completer.complete(msg);
        }
      } catch (e) {
        completer.completeError(e);
      }
    }

    _socket!.on('receiveMessage', handler);
    _socket!.emit('sendMessage', {'content': content});

    final result = await completer.future;

    // Remove temporary listener to avoid duplicates
    _socket!.off('receiveMessage', handler);

    return result;
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      _socket!.off('receiveMessage');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  bool get isConnected => _socket?.connected ?? false;
}
