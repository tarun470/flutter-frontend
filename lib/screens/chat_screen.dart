import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
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
  final socketService = SocketService();
  final messageController = TextEditingController();
  final secureStorage = SecureStorageService();
  final messageService = MessageService();
  final ScrollController scrollController = ScrollController();

  List<Message> messages = [];
  String? token;
  String? userId;
  String? username;
  String currentRoom = 'general';
  bool isTyping = false;
  Map<String, bool> typingUsers = {};
  int onlineCount = 0;
  Map<String, dynamic> onlineUsersMap = {};
  bool showEmoji = false;
  String? replyToMessageId;

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

  // ---------------- Initialization ----------------
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
    final hist = await messageService.fetchHistory(currentRoom);
    setState(() {
      messages = hist;
    });
    _scrollToBottom();
  }

  void _redirectToLogin() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ---------------- Socket ----------------
  void _connectSocket() {
    socketService.connect(token!, onConnect: () {
      socketService.joinRoom(currentRoom);

      socketService.onMessage = (msg) {
        setState(() {
          if (!messages.any((m) => m.id == msg.id)) messages.add(msg);
        });
        _scrollToBottom();
      };

      socketService.onTyping = (userIdTyping, typing, usernameTyping) {
        setState(() {
          if (typing) typingUsers[userIdTyping] = true;
          else typingUsers.remove(userIdTyping);
        });
      };

      socketService.onOnlineUsers = (count, usersMap) {
        setState(() {
          onlineCount = count;
          onlineUsersMap = usersMap ?? {};
        });
      };

      socketService.onMessageEdited = (msg) {
        setState(() {
          final idx = messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) messages[idx] = msg;
        });
      };

      socketService.onMessageDeleted = (msg) {
        setState(() {
          messages.removeWhere((m) => m.id == msg.id);
        });
      };

      socketService.onReactionUpdated = (payload) {
        final mid = payload['messageId'];
        final reactions = Map<String, dynamic>.from(payload['reactions'] ?? {});
        setState(() {
          final idx = messages.indexWhere((m) => m.id == mid);
          if (idx != -1) messages[idx].reactions = reactions.map((k, v) => MapEntry(k, v as int));
        });
      };
    }, onDisconnect: () {});
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------- Typing ----------------
  void _onTextChanged(String text) {
    final currentlyTyping = text.isNotEmpty;
    if (currentlyTyping != isTyping) {
      isTyping = currentlyTyping;
      socketService.sendTyping(currentRoom, userId ?? '', username ?? '', isTyping);
    }
  }

  // ---------------- Send / Edit / Delete / Reaction ----------------
  Future<void> _sendText({String? forcedReplyTo}) async {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = Message(
      id: tempId,
      senderId: userId ?? '',
      senderName: username ?? '',
      roomId: currentRoom,
      content: content,
      type: 'text',
      timestamp: DateTime.now(),
      isDelivered: false,
      isSeen: false,
      reactions: {},
      replyToMessageId: replyToMessageId ?? forcedReplyTo,
    );

    setState(() {
      messages.add(tempMessage);
      messageController.clear();
      replyToMessageId = null;
      showEmoji = false;
    });
    _scrollToBottom();

    socketService.sendMessage(
      content,
      roomId: currentRoom,
      senderName: username ?? '',
      tempId: tempId,
      replyTo: tempMessage.replyToMessageId,
    );
  }

  void _editMessage(String messageId, String newText) {
    socketService.editMessage(messageId, newText);
  }

  void _deleteMessage(String messageId, {bool forEveryone = false}) {
    socketService.deleteMessage(messageId, forEveryone: forEveryone);
  }

  void _addReaction(String messageId, String emoji) {
    socketService.addReaction(messageId, emoji);
  }

  // ---------------- Image / File ----------------
  Future<void> _pickImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final picked = fromCamera
        ? await picker.pickImage(source: ImageSource.camera, maxWidth: 1600)
        : await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;

    final upload = await ApiService.uploadFile(picked.path, 'file', token: token);
    if (upload == null) return;

    final url = upload['url'] ?? upload['path'] ?? upload['fileUrl'];
    if (url == null) return;
    socketService.sendImage(url, roomId: currentRoom, senderName: username ?? '');
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    final filename = res.files.single.name;
    if (path == null) return;

    final upload = await ApiService.uploadFile(path, 'file', token: token, filename: filename);
    if (upload == null) return;

    final url = upload['url'] ?? upload['path'] ?? upload['fileUrl'];
    if (url == null) return;
    socketService.sendFile(url, filename, roomId: currentRoom, senderName: username ?? '');
  }

  // ---------------- UI Helpers ----------------
  Future<Message?> _findMessageById(String id) async {
    final m = messages.firstWhere(
      (x) => x.id == id,
      orElse: () => Message(
        id: '',
        senderId: '',
        senderName: '',
        roomId: '',
        content: '',
        type: 'text',
        timestamp: DateTime.now(),
      ),
    );
    return m.id.isEmpty ? null : m;
  }

  Widget _buildMessageTile(Message m) {
    final isMe = m.senderId == (userId ?? '');
    final timeStr = DateFormat('hh:mm a').format(m.timestamp.toLocal());
    final showReply = m.replyToMessageId != null && m.replyToMessageId!.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(m),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMe
                    ? [Colors.cyanAccent.withOpacity(0.25), Colors.blueAccent]
                    : [Colors.blueGrey.shade800, Colors.indigo.shade700],
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(6),
                bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) Text(m.senderName, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                if (showReply)
                  FutureBuilder<Message?>(
                    future: _findMessageById(m.replyToMessageId!),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final replied = snap.data!;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                        child: Text('${replied.senderName}: ${replied.content}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      );
                    },
                  ),
                if (m.type == 'text')
                  Text(m.content, style: const TextStyle(color: Colors.white, fontSize: 15))
                else if (m.type == 'image')
                  GestureDetector(
                    onTap: () => _showFullImage(m.content),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(m.content, height: 160, fit: BoxFit.cover)),
                  )
                else if (m.type == 'file')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insert_drive_file, color: Colors.white70),
                      const SizedBox(width: 8),
                      Flexible(child: Text(m.content, style: const TextStyle(color: Colors.white70))),
                    ],
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeStr, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(width: 8),
                    if (isMe) _buildTickWidget(m),
                    const SizedBox(width: 6),
                    if (m.reactions != null && m.reactions!.isNotEmpty) _buildReactionsRow(m),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTickWidget(Message m) {
    if (m.isSeen) return const Icon(Icons.done_all, color: Colors.blue, size: 16);
    if (m.isDelivered) return const Icon(Icons.done_all, color: Colors.white70, size: 16);
    return const Icon(Icons.check, color: Colors.white70, size: 14);
  }

  Widget _buildReactionsRow(Message m) {
    return Row(
      children: m.reactions!.entries.map((e) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text(e.key),
            const SizedBox(width: 6),
            Text('${e.value}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        );
      }).toList(),
    );
  }

  void _onMessageLongPress(Message m) async {
    final isMe = m.senderId == (userId ?? '');
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.reply), title: const Text('Reply'), onTap: () => Navigator.pop(c, 'reply')),
              if (isMe) ListTile(leading: const Icon(Icons.edit), title: const Text('Edit'), onTap: () => Navigator.pop(c, 'edit')),
              if (isMe) ListTile(leading: const Icon(Icons.delete), title: const Text('Delete for me'), onTap: () => Navigator.pop(c, 'delete_local')),
              if (isMe) ListTile(leading: const Icon(Icons.delete_forever), title: const Text('Delete for everyone'), onTap: () => Navigator.pop(c, 'delete_everyone')),
              ListTile(leading: const Icon(Icons.emoji_emotions), title: const Text('React'), onTap: () => Navigator.pop(c, 'react')),
              ListTile(leading: const Icon(Icons.share), title: const Text('Forward (not implemented)'), onTap: () => Navigator.pop(c, 'forward')),
              ListTile(leading: const Icon(Icons.close), title: const Text('Cancel'), onTap: () => Navigator.pop(c, null)),
            ],
          ),
        );
      },
    );

    if (choice == null) return;
    if (choice == 'reply') setState(() => replyToMessageId = m.id);
    if (choice == 'edit') {
      final edited = await _showEditDialog(m.content);
      if (edited != null && edited.trim().isNotEmpty) _editMessage(m.id, edited.trim());
    }
    if (choice == 'delete_local') _deleteMessage(m.id, forEveryone: false);
    if (choice == 'delete_everyone') _deleteMessage(m.id, forEveryone: true);
    if (choice == 'react') {
      final emoji = await _showEmojiPickerDialog();
      if (emoji != null) _addReaction(m.id, emoji);
    }
  }

  Future<String?> _showEditDialog(String oldText) async {
    final ctrl = TextEditingController(text: oldText);
    final res = await showDialog<String?>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Save')),
          ],
        );
      },
    );
    return res;
  }

  Future<String?> _showEmojiPickerDialog() async {
    String? chosen;
    await showModalBottomSheet(
      context: context,
      builder: (c) {
        return SizedBox(
          height: 320,
          child: EmojiPicker(
            onEmojiSelected: (cat, emoji) {
              chosen = emoji.emoji;
              Navigator.pop(c);
            },
            config: const Config(columns: 8, emojiSizeMax: 32),
          ),
        );
      },
    );
    return chosen;
  }

  void _showFullImage(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(),
        backgroundColor: Colors.black,
        body: Center(child: Image.network(url)),
      ),
    ));
  }

  // ---------------- Top bar / Online users ----------------
  PreferredSizeWidget _buildTopBar() {
    final typingCount = typingUsers.length;
    final typingLabel = typingCount > 0 ? 'typing...' : '';
    final onlineLabel = '$onlineCount online';
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(currentRoom, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(typingCount > 0 ? typingLabel : onlineLabel, style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.people), onPressed: _showOnlineUsers),
        IconButton(icon: const Icon(Icons.image), onPressed: () => _pickImage(fromCamera: false)),
        IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => _pickImage(fromCamera: true)),
        IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickFile),
        IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
      ],
    );
  }

  Future<void> _showOnlineUsers() async {
    await showModalBottomSheet(
      context: context,
      builder: (c) {
        final entries = onlineUsersMap.entries.toList();
        return SafeArea(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final id = entries[i].key;
              final data = Map<String, dynamic>.from(entries[i].value);
              final name = data['username'] ?? data['name'] ?? id;
              final lastSeen = data['lastSeen'];
              return ListTile(
                leading: CircleAvatar(child: Text(name[0])),
                title: Text(name),
                subtitle: Text(data['isOnline'] == true ? 'Online' : (lastSeen ?? 'Last seen unknown')),
              );
            },
          ),
        );
      },
    );
  }

  void _logout() async {
    socketService.disconnect();
    await secureStorage.clearAll();
    _redirectToLogin();
  }

  // ---------------- Input area ----------------
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions, color: Colors.white70),
            onPressed: () => setState(() => showEmoji = !showEmoji),
          ),
          Expanded(
            child: TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white38),
              ),
              onChanged: _onTextChanged,
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendText,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: messages.length,
              itemBuilder: (context, i) => _buildMessageTile(messages[i]),
            ),
          ),
          if (showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (cat, emoji) {
                  messageController.text += emoji.emoji;
                  _onTextChanged(messageController.text);
                },
                config: const Config(columns: 8, emojiSizeMax: 32),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }
}
