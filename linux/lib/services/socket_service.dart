import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

typedef MessageCallback = void Function(Map<String, dynamic> data);

class SocketService {
  // ✅ Singleton pattern — ensures only ONE socket connection exists app-wide
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  /// ✅ Connect to Socket.IO server with JWT
  void connect(
    String token, {
    String url = 'http://localhost:5000',
    void Function()? onConnect,
    void Function()? onDisconnect,
    void Function(dynamic)? onError,
  }) {
    // Prevent duplicate connections
    if (_socket != null && _socket!.connected) {
      print('⚠️ Socket already connected');
      return;
    }

    print('🔌 Connecting to Socket.IO...');

    _socket = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          // ❌ removed enableForceNew() → was causing multiple socket IDs
          .enableAutoConnect() // allows reconnect automatically
          .setQuery({'token': token}) // send JWT to backend
          .build(),
    );

    // --- Events ---
    _socket!.onConnect((_) {
      print('✅ Socket connected: ${_socket!.id}');
      onConnect?.call();
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket disconnected');
      onDisconnect?.call();
    });

    _socket!.onError((data) {
      print('⚠️ Socket error: $data');
      onError?.call(data);
    });

    _socket!.onConnectError((data) {
      print('⚠️ Socket connection error: $data');
      onError?.call(data);
    });

    _socket!.onReconnect((_) => print('🔄 Socket reconnected'));
    _socket!.onReconnectAttempt((_) => print('⏳ Socket reconnecting...'));
  }

  /// ✅ Listen for incoming messages
  void listenMessage(MessageCallback callback) {
    _socket?.off('receiveMessage'); // remove old listener to avoid duplicates

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

  /// ✅ Send message to server
  void sendMessage(String content) {
    if (_socket == null || !_socket!.connected) {
      print('⚠️ Cannot send — socket not connected');
      return;
    }

    final message = {'content': content};
    print('📤 Sending message: $message');
    _socket!.emit('sendMessage', message);
  }

  /// ✅ Disconnect cleanly
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

  /// ✅ Getter to check connection status
  bool get isConnected => _socket?.connected ?? false;
}





