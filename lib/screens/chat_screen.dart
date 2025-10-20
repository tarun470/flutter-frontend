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

class _ChatScreenState extends State<ChatScreen> {
  final socketService = SocketService();
  final messageController = TextEditingController();
  final secureStorage = SecureStorageService();
  final ScrollController scrollController = ScrollController();

  List<Message> messages = [];
  String? token;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    token = await secureStorage.getToken();
    userId = await secureStorage.getUserId();
    if (token != null && userId != null) _connectSocket();
    else _redirectToLogin();
  }

  void _connectSocket() {
    socketService.connect(token!,
        onConnect: () => print('✅ Socket connected'),
        onDisconnect: () => print('❌ Socket disconnected'));

    socketService.listenMessage((msg) {
      setState(() {
        // Replace temp message if content & sender match
        final index = messages.indexWhere((m) =>
            m.senderId == msg.senderId &&
            m.content == msg.content &&
            m.timestamp.difference(msg.timestamp).inSeconds.abs() < 5);
        if (index != -1) messages[index] = msg;
        else if (!messages.any((m) => m.id == msg.id)) messages.add(msg);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void sendMessage() {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    final tempMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: userId ?? '',
      content: content,
      timestamp: DateTime.now(),
    );
    setState(() => messages.add(tempMsg));
    _scrollToBottom();

    socketService.sendMessage(content);
    messageController.clear();
  }

  Future<void> logout() async {
    socketService.disconnect();
    await secureStorage.clearAll();
    _redirectToLogin();
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 4),
            Text(DateFormat('hh:mm a').format(message.timestamp),
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Send a message...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => sendMessage(),
            ),
          ),
          IconButton(
            onPressed: sendMessage,
            icon: const Icon(Icons.send, color: Colors.cyanAccent),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == (userId ?? '');
                  return buildMessageBubble(message, isMe);
                },
              ),
            ),
            buildInputArea(),
          ],
        ),
      ),
    );
  }
}
