import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/message_service.dart';
import '../utils/secure_storage.dart';
import '../models/message.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  // CONTROLLERS
  final messageCtrl = TextEditingController();
  final scrollCtrl = ScrollController();

  // SERVICES
  final socketService = SocketService();
  final storage = SecureStorageService();
  final msgService = MessageService();

  // USER INFO
  String? userId;
  String? username;
  String? token;

  // CHAT STATE
  List<Message> messages = [];
  bool showEmoji = false;
  bool loadingHistory = true;
  bool sending = false;

  String currentRoom = "general";
  int onlineCount = 0;

  String? replyToMessageId;
  Map<String, String> typingUsers = {}; // userId → username

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    messageCtrl.dispose();
    scrollCtrl.dispose();
    socketService.disconnect();
    super.dispose();
  }

  // -------------------------------------------------------------
  // INIT USER + HISTORY
  // -------------------------------------------------------------
  Future<void> _initUser() async {
    token = await storage.getToken();
    userId = await storage.getUserId();
    username = await storage.getUsername();

    if (token == null || userId == null) {
      _goToLogin();
      return;
    }

    await _loadHistory();
    _connectSocket();
  }

  Future<void> _loadHistory() async {
    setState(() => loadingHistory = true);

    messages = await msgService.fetchHistory(currentRoom);

    setState(() => loadingHistory = false);
    _scrollBottom();
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // -------------------------------------------------------------
  // SOCKET CONNECTION + LISTENERS
  // -------------------------------------------------------------
  void _connectSocket() {
    socketService.connect(token!, onConnect: () {
      socketService.joinRoom(currentRoom);

      socketService.onMessage = (msg) {
        if (!messages.any((m) => m.id == msg.id)) {
          setState(() => messages.add(msg));
          _scrollBottom();
        }
      };

      // TYPING USERS
      socketService.onTyping = (uid, isTyping, uname) {
        if (uid == userId) return;

        setState(() {
          if (isTyping) {
            typingUsers[uid] = uname ?? "User";
          } else {
            typingUsers.remove(uid);
          }
        });
      };

      socketService.onOnlineUsers = (count, _) {
        setState(() => onlineCount = count);
      };

      // ✔ Delivered
      socketService.onMessageDelivered = (m) {
        final i = messages.indexWhere((x) => x.id == m.id);
        if (i != -1) {
          setState(() {
            messages[i].isDelivered = true;
            messages[i].deliveredTo = m.deliveredTo;
          });
        }
      };

      // ✔✔ Seen
      socketService.onMessageSeen = (m) {
        final i = messages.indexWhere((x) => x.id == m.id);
        if (i != -1) {
          setState(() {
            messages[i].isSeen = true;
            messages[i].seenBy = m.seenBy;
          });
        }
      };
    });
  }

  // -------------------------------------------------------------
  // SCROLL
  // -------------------------------------------------------------
  void _scrollBottom({int delay = 70}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (!scrollCtrl.hasClients) return;
      scrollCtrl.animateTo(
        scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  // -------------------------------------------------------------
  // SEND TEXT MESSAGE
  // -------------------------------------------------------------
  Future<void> _sendText() async {
    final text = messageCtrl.text.trim();
    if (text.isEmpty || sending) return;

    sending = true;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final msg = Message(
      id: tempId,
      senderId: userId!,
      senderName: username!,
      roomId: currentRoom,
      content: text,
      type: "text",
      timestamp: DateTime.now(),
      reactions: {},
      deliveredTo: [],
      seenBy: [],
      replyToMessageId: replyToMessageId,
    );

    setState(() {
      messages.add(msg);
      messageCtrl.clear();
      replyToMessageId = null;
      showEmoji = false;
    });

    socketService.sendMessage(
      text,
      roomId: currentRoom,
      senderName: username!,
      tempId: tempId,
      replyTo: replyToMessageId,
    );

    socketService.sendTyping(currentRoom, userId!, username!, false);

    sending = false;
    _scrollBottom();
  }

  // -------------------------------------------------------------
  // SEND IMAGE
  // -------------------------------------------------------------
  Future<void> _sendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);

      if (picked == null) return;

      final uploaded = await ApiService.uploadFile(
        picked.path,
        "image",
        token: token,
        filename: picked.name,
      );

      if (uploaded == null) return;

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      final msg = Message(
        id: tempId,
        senderId: userId!,
        senderName: username!,
        roomId: currentRoom,
        content: uploaded.fileUrl!,
        type: "image",
        timestamp: DateTime.now(),
        reactions: {},
        deliveredTo: [],
        seenBy: [],
        fileUrl: uploaded.fileUrl,
        fileName: uploaded.fileName,
      );

      setState(() => messages.add(msg));
      _scrollBottom();

      socketService.sendFile(
        uploaded.fileUrl!,
        uploaded.fileName!,
        roomId: currentRoom,
        senderName: username!,
      );
    } catch (e) {
      print("Image send error: $e");
    }
  }

  // -------------------------------------------------------------
  // SEND FILE
  // -------------------------------------------------------------
  Future<void> _sendFile() async {
    try {
      final res = await FilePicker.platform.pickFiles();
      if (res == null) return;

      final path = res.files.single.path!;
      final name = res.files.single.name;

      final uploaded = await ApiService.uploadFile(
        path,
        "file",
        token: token,
        filename: name,
      );

      if (uploaded == null) return;

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      final msg = Message(
        id: tempId,
        senderId: userId!,
        senderName: username!,
        roomId: currentRoom,
        content: uploaded.fileUrl!,
        type: "file",
        timestamp: DateTime.now(),
        reactions: {},
        deliveredTo: [],
        seenBy: [],
        fileUrl: uploaded.fileUrl,
        fileName: uploaded.fileName,
      );

      setState(() => messages.add(msg));
      _scrollBottom();

      socketService.sendFile(
        uploaded.fileUrl!,
        uploaded.fileName!,
        roomId: currentRoom,
        senderName: username!,
      );
    } catch (e) {
      print("Upload error: $e");
    }
  }

  // -------------------------------------------------------------
  // WHATSAPP ✔✔ Ticks UI
  // -------------------------------------------------------------
  Widget _tick(Message m) {
    if (m.senderId != userId) return const SizedBox();

    if (!m.isDelivered) {
      return const Icon(Icons.check, size: 16, color: Colors.white38);
    }

    if (!m.isSeen) {
      return const Icon(Icons.done_all, size: 16, color: Colors.white70);
    }

    return const Icon(Icons.done_all, size: 16, color: Colors.lightBlueAccent);
  }

  // -------------------------------------------------------------
  // TYPING
  // -------------------------------------------------------------
  Widget _typingIndicator() {
    if (typingUsers.isEmpty) return const SizedBox();

    final names = typingUsers.values.join(", ");

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "$names is typing...",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MESSAGE BUBBLE (Now includes image + ticks!)
  // -------------------------------------------------------------
  Widget _bubble(Message m) {
    final isMe = m.senderId == userId;
    final time = DateFormat('hh:mm a').format(m.timestamp);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(colors: [Color(0xFF0FD9FF), Color(0xFF0061FF)])
              : const LinearGradient(colors: [Color(0xFF232931), Color(0xFF1C2835)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (m.type == "image")
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  m.fileUrl ?? m.content,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else if (m.type == "file")
              Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.white70),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.fileName ?? "file",
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
              )
            else
              Text(m.content,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 10)),
                const SizedBox(width: 6),
                _tick(m),
              ],
            )
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // INPUT BAR
  // -------------------------------------------------------------
  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black,
      child: Row(
        children: [
          // Emoji toggle
          IconButton(
            icon: Icon(showEmoji ? Icons.keyboard : Icons.emoji_emotions),
            color: Colors.white70,
            onPressed: () => setState(() => showEmoji = !showEmoji),
          ),

          // Input field
          Expanded(
            child: TextField(
              controller: messageCtrl,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),

              onChanged: (txt) {
                socketService.sendTyping(
                    currentRoom, userId!, username!, txt.isNotEmpty);
              },

              decoration: const InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),

          // Attach File
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.white70),
            onPressed: _sendFile,
          ),

          // Image upload button
          IconButton(
            icon: const Icon(Icons.image, color: Colors.greenAccent),
            onPressed: _sendImage,
          ),

          // Send button
          IconButton(
            icon: const Icon(Icons.send, color: Colors.cyanAccent),
            onPressed: _sendText,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // BUILD UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "GENERAL ($onlineCount online)",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _bubble(messages[i]),
                  ),
          ),

          _typingIndicator(),

          if (showEmoji)
            SizedBox(
              height: 260,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  messageCtrl.text += emoji.emoji;
                },
                config: const Config(columns: 8),
              ),
            ),

          _inputBar(),
        ],
      ),
    );
  }
}
