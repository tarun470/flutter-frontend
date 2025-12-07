import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../services/socket_service.dart';
import '../services/message_service.dart';
import '../services/api_service.dart';
import '../utils/secure_storage.dart';
import '../models/message.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final SocketService socketService = SocketService();
  final TextEditingController messageController = TextEditingController();
  final SecureStorageService secureStorage = SecureStorageService();
  final MessageService messageService = MessageService();
  final ScrollController scrollController = ScrollController();

  List<Message> messages = [];
  String? userId;
  String? username;
  String? token;

  bool showEmoji = false;
  bool loadingHistory = true;
  bool sending = false;

  String currentRoom = "general";

  String? replyToMessageId;
  Map<String, bool> typingUsers = {};
  int onlineCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    messageController.dispose();
    scrollController.dispose();
    socketService.disconnect();
    super.dispose();
  }

  // -------------------------------------------------------------
  // INIT USER + LOAD HISTORY + CONNECT SOCKET
  // -------------------------------------------------------------
  Future<void> _initializeUser() async {
    token = await secureStorage.getToken();
    userId = await secureStorage.getUserId();
    username = await secureStorage.getUsername();

    if (token == null || userId == null) {
      _redirectToLogin();
      return;
    }

    await _loadHistory();
    _connectSocket();
  }

  Future<void> _loadHistory() async {
    setState(() => loadingHistory = true);

    final hist = await messageService.fetchHistory(currentRoom);
    setState(() {
      messages = hist;
      loadingHistory = false;
    });

    _scrollToBottom();
  }

  void _redirectToLogin() {
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
          _scrollToBottom();
        }
      };

      socketService.onTyping = (uid, typing, uname) {
        if (uid == userId) return;

        setState(() {
          if (typing) {
            typingUsers[uid] = true;
          } else {
            typingUsers.remove(uid);
          }
        });
      };

      socketService.onOnlineUsers = (count, map) {
        setState(() => onlineCount = count);
      };

      socketService.onMessageEdited = (msg) {
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          setState(() => messages[index] = msg);
        }
      };

      socketService.onMessageDeleted = (msg) {
        setState(() => messages.removeWhere((m) => m.id == msg.id));
      };

      socketService.onReactionUpdated = (payload) {
        final id = payload["messageId"];
        final index = messages.indexWhere((m) => m.id == id);
        if (index != -1) {
          messages[index].reactions =
              Map<String, int>.from(payload["reactions"] ?? {});
          setState(() {});
        }
      };

      socketService.onMessageDelivered = (msg) {
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          messages[index].isDelivered = true;
          messages[index].deliveredTo = msg.deliveredTo;
          setState(() {});
        }
      };

      socketService.onMessageSeen = (msg) {
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          messages[index].isSeen = true;
          messages[index].seenBy = msg.seenBy;
          setState(() {});
        }
      };
    });
  }

  // -------------------------------------------------------------
  // SCROLL TO BOTTOM
  // -------------------------------------------------------------
  void _scrollToBottom({int delay = 80}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // -------------------------------------------------------------
  // SEND MESSAGE
  // -------------------------------------------------------------
  Future<void> _sendText() async {
    final content = messageController.text.trim();
    if (content.isEmpty) return;
    if (sending) return;

    sending = true;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // ---- TEMP MESSAGE FOR UI ----
    final temp = Message(
      id: tempId,
      senderId: userId!,
      senderName: username!,
      roomId: currentRoom,
      content: content,
      type: "text",
      timestamp: DateTime.now(),
      reactions: {},
      deliveredTo: [],
      seenBy: [],
      replyToMessageId: replyToMessageId,
    );

    setState(() {
      messages.add(temp);
      messageController.clear();
      replyToMessageId = null;
      showEmoji = false;
    });

    _scrollToBottom();

    // ---- SEND TO SERVER ----
    socketService.sendMessage(
      content,
      roomId: currentRoom,
      senderName: username!,
      tempId: tempId,
      replyTo: temp.replyToMessageId,
    );

    sending = false;
  }

  // -------------------------------------------------------------
  // FILE UPLOAD
  // -------------------------------------------------------------
  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles();

      if (res == null || res.files.isEmpty) return;

      final path = res.files.single.path!;
      final name = res.files.single.name;

      final uploaded = await ApiService.uploadFile(
        path,
        "file",
        token: token,
        filename: name,
      );

      if (uploaded == null || uploaded.fileUrl == null) return;

      final tempId = DateTime.now().millisecondsSinceEpoch.toString();

      // Local preview message
      final temp = Message(
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
        fileName: uploaded.fileName ?? name,
      );

      setState(() => messages.add(temp));
      _scrollToBottom();

      // Send to server
      socketService.sendFile(
        uploaded.fileUrl!,
        uploaded.fileName ?? name,
        roomId: currentRoom,
        senderName: username!,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  // -------------------------------------------------------------
  // FIND MESSAGE BY ID (for reply preview)
  // -------------------------------------------------------------
  Message? _findMessage(String id) {
    try {
      return messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------
  // STATUS ICONS
  // -------------------------------------------------------------
  Widget _statusIcon(Message m) {
    if (m.senderId != userId) return const SizedBox();

    if (!m.isDelivered) {
      return const Icon(Icons.watch_later_outlined,
          size: 14, color: Colors.white38);
    }

    if (!m.isSeen) {
      return const Icon(Icons.done, size: 14, color: Colors.white70);
    }

    return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
  }

  // -------------------------------------------------------------
  // MESSAGE BUBBLE UI
  // -------------------------------------------------------------
  Widget _messageTile(Message m) {
    final isMe = (m.senderId == userId);
    final timeStr = DateFormat('hh:mm a').format(m.timestamp);

    final reply = m.replyToMessageId != null
        ? _findMessage(m.replyToMessageId!)
        : null;

    final bubbleColor = isMe
        ? const LinearGradient(
            colors: [Color(0xFF0fd9ff), Color(0xFF0061ff)])
        : const LinearGradient(
            colors: [Color(0xFF222831), Color(0xFF1B2A3A)]);

    return GestureDetector(
      onLongPress: () => _onLongPress(m),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: bubbleColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        m.senderName,
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),

                    if (reply != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6, top: 4),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${reply.senderName}: ${reply.content}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),

                    if (m.type == "image")
                      Image.network(m.content, width: 200, height: 140)
                    else if (m.type == "file")
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file,
                              color: Colors.white70),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(m.fileName ?? "file",
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      )
                    else
                      Text(
                        m.content,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                      ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(timeStr,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 10)),
                        const SizedBox(width: 6),
                        _statusIcon(m),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // LONG PRESS MENU
  // -------------------------------------------------------------
  void _onLongPress(Message m) async {
    final isMe = m.senderId == userId;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black87,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
              leading: const Icon(Icons.reply, color: Colors.white),
              title: const Text("Reply",
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(c, "reply")),
          if (isMe)
            ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text("Edit",
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(c, "edit")),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.white),
              title: const Text("Delete",
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(c, "del"),
            ),
          ListTile(
            leading:
                const Icon(Icons.emoji_emotions, color: Colors.white),
            title:
                const Text("React", style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(c, "react"),
          )
        ],
      ),
    );

    if (choice == "reply") {
      setState(() => replyToMessageId = m.id);
    }
  }

  // -------------------------------------------------------------
  // INPUT BAR
  // -------------------------------------------------------------
  Widget _inputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(showEmoji ? Icons.keyboard : Icons.emoji_emotions),
            color: Colors.white70,
            onPressed: () => setState(() => showEmoji = !showEmoji),
          ),
          Expanded(
            child: TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              minLines: 1,
              maxLines: 4,
              onChanged: (_) {},
              decoration: const InputDecoration(
                hintText: "Type a message…",
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.cyanAccent),
            onPressed: _sendText,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("GENERAL ($onlineCount online)"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _messageTile(messages[i]),
                  ),
          ),
          if (showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  messageController.text += emoji.emoji;
                },
                config: const Config(columns: 8),
              ),
            ),
          _inputArea(),
        ],
      ),
    );
  }
}

