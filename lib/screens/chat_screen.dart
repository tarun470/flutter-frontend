import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/socket_service.dart';
import '../utils/secure_storage.dart';
import '../models/message.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final socketService = SocketService();
  final messageController = TextEditingController();
  final secureStorage = SecureStorageService();
  final ScrollController scrollController = ScrollController();

  List<Message> messages = [];
  String? token;
  String? userId;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _initializeUser();
  }

  Future<void> _initializeUser() async {
    token = await secureStorage.getToken();
    userId = await secureStorage.getUserId();

    if (token != null && userId != null) {
      _connectSocket();
    } else {
      _redirectToLogin();
    }
  }

  void _connectSocket() {
    socketService.connect(
      token!,
      onConnect: () => debugPrint('✅ Socket connected'),
      onDisconnect: () => debugPrint('❌ Socket disconnected'),
      onError: (err) => debugPrint('⚠️ Socket error: $err'),
    );

    socketService.listenMessage((data) {
      final newMessage = Message.fromJson(data);

      // ✅ Avoid duplicates
      if (!messages.any((msg) => msg.id == newMessage.id)) {
        setState(() => messages.add(newMessage));
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void sendMessage() {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    // ✅ Do not add locally; server will broadcast with correct timestamp
    socketService.sendMessage(content);
    messageController.clear();
  }

  Future<void> logout() async {
    await socketService.disconnect();
    await secureStorage.clearAll();
    _redirectToLogin();
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isMe
                ? [Colors.cyanAccent.withOpacity(0.3), Colors.blueAccent]
                : [Colors.indigo.shade700, Colors.blueGrey.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(2, 3),
            ),
          ],
          border: Border.all(
            color: Colors.blueAccent.withOpacity(0.4),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Send a friendly message...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: sendMessage,
            icon: const Icon(Icons.send, color: Colors.cyanAccent, size: 26),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingHandshake(double width, double height) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final scale = 0.9 + 0.1 * _animationController.value;
        final opacity = 0.05 + 0.05 * _animationController.value;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Image.network(
              'https://cdn-icons-png.flaticon.com/512/616/616408.png',
              width: width,
              height: height,
              fit: BoxFit.cover,
              color: Colors.cyanAccent.withOpacity(0.15),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildPulsingHandshake(screenWidth, screenHeight)),
          SafeArea(
            child: Center(
              child: Column(
                children: [
                  // HEADER
                  Container(
                    width: screenWidth * 0.5,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.6),
                          blurRadius: 25,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🤝 CHAT ROOM 🤝',
                        style: TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.4,
                          shadows: [
                            Shadow(
                                blurRadius: 10,
                                color: Colors.cyanAccent,
                                offset: Offset(0, 0))
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // CHAT CONTAINER
                  Expanded(
                    child: Center(
                      child: Container(
                        width: screenWidth * 0.5,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF001F3F), Color(0xFF0A192F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isMe = message.senderId == userId;
                                  return buildMessageBubble(message, isMe);
                                },
                              ),
                            ),
                            buildInputArea(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

