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

  bool loadingHistory = true;
  bool sending = false;

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

  // ---------------- Socket ----------------
  void _connectSocket() {
    socketService.connect(token!, onConnect: () {
      socketService.joinRoom(currentRoom);

      socketService.onMessage = (msg) {
        final exists = messages.any((m) => m.id == msg.id);
        if (!exists) {
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

      socketService.onOnlineUsers = (count, usersMap) {
        setState(() {
          onlineCount = count;
          onlineUsersMap = usersMap ?? {};
        });
      };

      socketService.onMessageEdited = (msg) {
        setState(() {
          final index = messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) messages[index] = msg;
        });
      };

      socketService.onMessageDeleted = (msg) {
        setState(() => messages.removeWhere((m) => m.id == msg.id));
      };

      socketService.onReactionUpdated = (payload) {
        final id = payload['messageId'];
        final map = Map<String, int>.from(payload['reactions'] ?? {});
        setState(() {
          final index = messages.indexWhere((m) => m.id == id);
          if (index != -1) messages[index].reactions = map;
        });
      };

      socketService.onMessageDelivered = (msg) {
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          setState(() {
            messages[index].isDelivered = true;
            messages[index].deliveredTo = msg.deliveredTo;
          });
        }
      };

      socketService.onMessageSeen = (msg) {
        final index = messages.indexWhere((m) => m.id == msg.id);
        if (index != -1) {
          setState(() {
            messages[index].isSeen = true;
            messages[index].seenBy = msg.seenBy;
          });
        }
      };
    });
  }

  void _scrollToBottom({int delayMs = 80}) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ---------------- Typing ----------------
  void _onTextChanged(String text) {
    final t = text.trim().isNotEmpty;
    if (t != isTyping) {
      isTyping = t;
      if (userId != null && username != null) {
        socketService.sendTyping(currentRoom, userId!, username!, t);
      }
    }
  }

  // ---------------- Send Message ----------------
  Future<void> _sendText() async {
    if (sending) return;

    final content = messageController.text.trim();
    if (content.isEmpty || userId == null || username == null) return;

    sending = true;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    final temp = Message(
      id: tempId,
      senderId: userId!,
      senderName: username!,
      roomId: currentRoom,
      content: content,
      type: 'text',
      timestamp: DateTime.now(),
      reactions: {},
      replyToMessageId: replyToMessageId,
    );

    setState(() {
      messages.add(temp);
      messageController.clear();
      replyToMessageId = null;
      showEmoji = false;
    });

    _scrollToBottom();

    socketService.sendMessage(
      content,
      roomId: currentRoom,
      senderName: username!,
      tempId: tempId,
      replyTo: temp.replyToMessageId,
    );

    sending = false;
  }

  void _editMessage(String id, String newText) =>
      socketService.editMessage(id, newText);

  void _deleteMessage(String id, {bool forEveryone = false}) =>
      socketService.deleteMessage(id, forEveryone: forEveryone);

  void _addReaction(String id, String emoji) =>
      socketService.addReaction(id, emoji);

  // ---------------- File Picker ----------------
  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(withData: false);
      if (res == null || res.files.isEmpty) return;

      final path = res.files.single.path;
      final name = res.files.single.name;

      if (path == null) return;

      final upload = await ApiService.uploadFile(
        path,
        'file',
        token: token,
        filename: name,
      );

      // Our ApiService returns MessageModel? with fileUrl & fileName
      if (upload == null || upload.fileUrl == null) return;

      socketService.sendFile(
        upload.fileUrl!,
        upload.fileName ?? name,
        roomId: currentRoom,
        senderName: username ?? '',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File upload failed: $e")),
      );
    }
  }

  // ---------------- Find Reply ----------------
  Message? _findMessage(String id) {
    try {
      return messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------- UI Helper ----------------
  Widget _statusIcon(Message m) {
    if (m.senderId != userId) return const SizedBox.shrink();

    if (!m.isDelivered) {
      return const Icon(Icons.watch_later_outlined,
          size: 14, color: Colors.white38);
    }

    if (!m.isSeen) {
      return const Icon(Icons.done, size: 14, color: Colors.white70);
    }

    return const Icon(Icons.done_all,
        size: 14, color: Colors.lightBlueAccent);
  }

  // ---------------- Image Preview ----------------
  Widget _imagePreview(String url) {
    return GestureDetector(
      onTap: () => showDialog(
        barrierColor: Colors.black87,
        context: context,
        builder: (_) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(child: InteractiveViewer(child: Image.network(url))),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 200,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 200,
            height: 140,
            color: Colors.white12,
            child: const Icon(Icons.broken_image, color: Colors.white30),
          ),
        ),
      ),
    );
  }

  // ---------------- File View ----------------
  Widget _fileCard(String url, String name) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file,
              size: 32, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('File URL'),
                content: SelectableText(url),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Reactions Row ----------------
  Widget _reactionsRow(Message m) {
    if (m.reactions == null || m.reactions!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        children: m.reactions!.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 3),
                Text(
                  e.value.toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------- Message Tile ----------------
  Widget _messageTile(Message m) {
    final isMe = m.senderId == userId;
    final timeStr = DateFormat('hh:mm a').format(m.timestamp.toLocal());
    final replied = m.replyToMessageId != null
        ? _findMessage(m.replyToMessageId!)
        : null;

    final bubbleColor = isMe
        ? const LinearGradient(
            colors: [Color(0xFF0fd9ff), Color(0xFF0061ff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF222831), Color(0xFF1B2A3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return GestureDetector(
      onLongPress: () => _onLongPress(m),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight:
                      isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  if (isMe)
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.18),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                    ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          m.senderName,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),

                    if (replied != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${replied.senderName}: ${replied.content}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    if (m.type == 'image')
                      _imagePreview(m.content)
                    else if (m.type == 'file')
                      _fileCard(m.content, m.fileName ?? "file")
                    else
                      Text(
                        m.content,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, height: 1.3),
                      ),

                    _reactionsRow(m),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                        _statusIcon(m),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Long press actions ----------------
  void _onLongPress(Message m) async {
    final isMe = m.senderId == userId;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF10131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            ListTile(
                title: const Text("Reply", style: TextStyle(color: Colors.white)),
                leading: const Icon(Icons.reply, color: Colors.white70),
                onTap: () => Navigator.pop(c, "reply")),
            if (isMe)
              ListTile(
                  title:
                      const Text("Edit", style: TextStyle(color: Colors.white)),
                  leading: const Icon(Icons.edit, color: Colors.white70),
                  onTap: () => Navigator.pop(c, "edit")),
            if (isMe)
              ListTile(
                  title: const Text("Delete for me",
                      style: TextStyle(color: Colors.white)),
                  leading: const Icon(Icons.delete, color: Colors.white70),
                  onTap: () => Navigator.pop(c, "del_local")),
            if (isMe)
              ListTile(
                  title: const Text("Delete for everyone",
                      style: TextStyle(color: Colors.white)),
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.white70),
                  onTap: () => Navigator.pop(c, "del_all")),
            ListTile(
                title:
                    const Text("React", style: TextStyle(color: Colors.white)),
                leading:
                    const Icon(Icons.emoji_emotions, color: Colors.white70),
                onTap: () => Navigator.pop(c, "react")),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );

    if (choice == null) return;

    if (choice == "reply") {
      setState(() => replyToMessageId = m.id);
    } else if (choice == "edit") {
      final edited = await _editDialog(m.content);
      if (edited != null && edited.trim().isNotEmpty) {
        _editMessage(m.id, edited.trim());
      }
    } else if (choice == "del_local") {
      _deleteMessage(m.id, forEveryone: false);
    } else if (choice == "del_all") {
      _deleteMessage(m.id, forEveryone: true);
    } else if (choice == "react") {
      final emoji = await _emojiPicker();
      if (emoji != null) _addReaction(m.id, emoji);
    }
  }

  Future<String?> _editDialog(String oldText) async {
    final ctrl = TextEditingController(text: oldText);

    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text("Edit message"),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, null),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text("Save")),
        ],
      ),
    );
  }

  Future<String?> _emojiPicker() async {
    String? chosen;

    await showModalBottomSheet(
      context: context,
      builder: (c) => SizedBox(
        height: 300,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            chosen = emoji.emoji;
            Navigator.pop(c);
          },
          config: const Config(columns: 8, emojiSizeMax: 32),
        ),
      ),
    );

    return chosen;
  }

  // ---------------- AppBar ----------------
  PreferredSizeWidget _topBar() {
    final typing = typingUsers.isNotEmpty
        ? (typingUsers.length == 1 ? "typing…" : "${typingUsers.length} typing…")
        : "$onlineCount online";

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.black,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF000814), Color(0xFF001D3D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentRoom.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            typing,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: _pickFile,
        ),
        IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
      ],
    );
  }

  void _logout() async {
    socketService.disconnect();
    await secureStorage.clearAll();
    _redirectToLogin();
  }

  // ---------------- Reply Banner ----------------
  Widget _replyBanner() {
    if (replyToMessageId == null) return const SizedBox.shrink();
    final replied = _findMessage(replyToMessageId!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.cyanAccent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              replied == null
                  ? "Replying…"
                  : "${replied.senderName}: ${replied.content}",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
            onPressed: () => setState(() => replyToMessageId = null),
          ),
        ],
      ),
    );
  }

  // ---------------- Input box ----------------
  Widget _inputArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
              icon: Icon(
                showEmoji ? Icons.keyboard : Icons.emoji_emotions,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => showEmoji = !showEmoji)),
          Expanded(
            child: TextField(
              controller: messageController,
              style: const TextStyle(color: Colors.white),
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.white38),
                  hintText:
                      replyToMessageId != null ? "Replying…" : "Type a message…"),
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _sendText(),
            ),
          ),
          IconButton(
              icon: const Icon(Icons.send, color: Colors.cyanAccent),
              onPressed: _sendText),
        ],
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (showEmoji) {
          setState(() => showEmoji = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _topBar(),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF020817), Color(0xFF050B18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: loadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 80, top: 6),
                            itemCount: messages.length,
                            itemBuilder: (_, i) => _messageTile(messages[i]),
                          ),
                          if (typingUsers.isNotEmpty)
                            Positioned(
                              left: 12,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white24, width: 0.5),
                                ),
                                child: Text(
                                  typingUsers.length == 1
                                      ? "typing…"
                                      : "${typingUsers.length} typing…",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            )
                        ],
                      ),
              ),
              _replyBanner(),
              if (showEmoji)
                SizedBox(
                  height: 260,
                  child: EmojiPicker(
                    onEmojiSelected: (_, emoji) {
                      messageController.text += emoji.emoji;
                      _onTextChanged(messageController.text);
                    },
                    config: const Config(columns: 8, emojiSizeMax: 32),
                  ),
                ),
              _inputArea(),
            ],
          ),
        ),
      ),
    );
  }
}
