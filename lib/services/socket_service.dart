import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef MessageCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  /// Connect to Socket.IO server with JWT
  void connect(
    String token, {
    String url = 'https://chat-backend.onrender.com', // ✅ deployed backend
    void Function()? onConnect,
    void Function()? onDisconnect,
    void Function(dynamic)? onError,
  }) {
    if (_socket != null && _socket!.connected) {
      print('⚠️ Socket already connected');
      return;
    }

    print('🔌 Connecting to Socket.IO at $url...');

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setQuery({'token': token})
          .build(),
    );

    // --- Events ---
    _socket!
      ..onConnect((_) {
        print('✅ Socket connected: ${_socket!.id}');
        onConnect?.call();
      })
      ..onDisconnect((_) {
        print('❌ Socket disconnected');
        onDisconnect?.call();
      })
      ..onError((data) {
        print('⚠️ Socket error: $data');
        onError?.call(data);
      })
      ..onConnectError((data) {
        print('⚠️ Socket connection error: $data');
        onError?.call(data);
      })
      ..onReconnect((_) => print('🔄 Socket reconnected'))
      ..onReconnectAttempt((_) => print('⏳ Socket reconnecting...'));
  }

  /// Listen for incoming messages
  void listenMessage(MessageCallback callback) {
    _socket?.off('receiveMessage'); // remove old listener
    _socket?.on('receiveMessage', (data) {
      try {
        final message = data is String
            ? jsonDecode(data)
            : Map<String, dynamic>.from(data);
        print('📩 Message received: $message');
        callback(message);
      } catch (e) {
        print('⚠️ Message parse error: $e');
      }
    });
  }

  /// Send message to server
  void sendMessage(String content) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Cannot send — socket not connected');
      return;
    }

    final message = {'content': content};
    print('📤 Sending message: $message');
    _socket!.emit('sendMessage', message);
  }

  /// Disconnect cleanly
  Future<void> disconnect() async {
    if (_socket != null) {
      print('🔌 Disconnecting socket...');
      _socket!.off('receiveMessage');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      print('❌ Socket fully disconnected');
    }
  }

  /// Check connection status
  bool get isConnected => _socket?.connected ?? false;
}
