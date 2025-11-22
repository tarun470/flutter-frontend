import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io' show Platform;

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
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
          if (typing) {
            typingUsers[userIdTyping] = true;
          } else {
            typingUsers.remove(userIdTyping);
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
          if (idx != -1) {
            messages[idx].reactions =
                reactions.map((k, v) => MapEntry(k, v as int));
          }
        });
      };

      // message delivered / seen handlers (if your SocketService exposes them)
      socketService.onMessageDelivered = (msg) {
        setState(() {
          final idx = messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            messages[idx].isDelivered = true;
            messages[idx].deliveredTo = msg.deliveredTo ?? messages[idx].deliveredTo;
          }
        });
      };

      socketService.onMessageSeen = (msg) {
        setState(() {
          final idx = messages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            messages[idx].isSeen = true;
            messages[idx].seenBy = msg.seenBy ?? messages[idx].seenBy;
          }
        });
      };

    }, onDisconnect: () {});
  }

  void _scrollToBottom({int delayMs = 150}) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + 160,
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
  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    if (res == null || res.files.isEmpty) return;

    final path = res.files.single.path;
    final filename = res.files.single.name;
    if (path == null) return;

    final uploadObj = await ApiService.uploadFile(
        path, 'file', token: token, filename: filename);
    final upload = uploadObj as Map<String, dynamic>?; // type-safe
    if (upload == null) return;

    final url = upload['url'] ?? upload['path'] ?? upload['fileUrl'];
    if (url == null) return;

    socketService.sendFile(
        url, filename, roomId: currentRoom, senderName: username ?? '');
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

  // Helper: render status ticks
  Widget _buildStatusIcon(Message m) {
    if (m.senderId != (userId ?? '')) return const SizedBox.shrink();

    // sending (no server ack yet)
    if (!m.isDelivered && !m.isSeen) {
      return const Icon(Icons.watch_later_outlined, size: 14, color: Colors.white38);
    }

    // delivered only
    if (m.isDelivered && !m.isSeen) {
      return const Icon(Icons.done, size: 14, color: Colors.white70);
    }

    // seen
    if (m.isSeen) {
      return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
    }

    return const SizedBox.shrink();
  }

  Widget _buildImagePreview(String url) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black87,
              child: Center(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 180,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 180,
            height: 120,
            color: Colors.white12,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.white30)),
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(String url, String filename) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 36, color: Colors.white70),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(filename, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('Tap to open', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70),
            onPressed: () {
              // open in browser (works on web & mobile with url_launcher if added)
              // fallback: copy to clipboard or show dialog
              // For now, show dialog with URL
              showDialog(context: context, builder: (_) {
                return AlertDialog(
                  title: const Text('File URL'),
                  content: SelectableText(url),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                  ],
                );
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildMessageTile(Message m) {
    final isMe = m.senderId == (userId ?? '');
    final timeStr = DateFormat('hh:mm a').format(m.timestamp.toLocal());
    final showReply = m.replyToMessageId != null && m.replyToMessageId!.isNotEmpty;

    // shadow-frame watermark border (subtle)
    final bubbleDecoration = BoxDecoration(
      gradient: LinearGradient(
        colors: isMe
            ? [Colors.cyanAccent.withOpacity(0.12), Colors.blueAccent]
            : [Colors.blueGrey.shade800, Colors.indigo.shade700],
      ),
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(6),
        bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(18),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
        // subtle inner border
        BoxShadow(
          color: Colors.white.withOpacity(0.02),
          blurRadius: 1,
          spreadRadius: 0.5,
          offset: const Offset(0, 0),
        ),
      ],
    );

    return GestureDetector(
      onLongPress: () => _onMessageLongPress(m),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: bubbleDecoration,
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Text(
                    m.senderName,
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                if (showReply)
                  FutureBuilder<Message?>(
                    future: _findMessageById(m.replyToMessageId!),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final replied = snap.data!;
                      return Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${replied.senderName}: ${replied.content}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                // Content: either text / image / file
                if (m.type == 'image' && (m.content.isNotEmpty))
                  _buildImagePreview(m.content)
                else if (m.type == 'file' && (m.content.isNotEmpty))
                  _buildFileCard(m.content, m.fileName ?? 'file')
                else
                  Text(m.content, style: const TextStyle(color: Colors.white, fontSize: 15)),

                const SizedBox(height: 8),

                // Time + status on same row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeStr, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    const SizedBox(width: 8),
                    _buildStatusIcon(m),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
          backgroundColor: Colors.grey[900],
          title: const Text('Edit Message'),
          content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white)),
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

  // ---------------- Top bar ----------------
  PreferredSizeWidget _buildTopBar() {
    final typingCount = typingUsers.length;
    final typingLabel = typingCount > 0 ? (typingUsers.length == 1 ? 'typing...' : 'multiple typing...') : '';
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                child: Text('Online — $onlineCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final id = entries[i].key;
                    final data = Map<String, dynamic>.from(entries[i].value);
                    final name = data['username'] ?? data['name'] ?? id;
                    final lastSeen = data['lastSeen'];
                    return ListTile(
                      leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
                      title: Text(name),
                      subtitle: Text(data['isOnline'] == true ? 'Online' : (lastSeen ?? 'Last seen unknown')),
                    );
                  },
                ),
              )
            ],
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
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
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: replyToMessageId != null ? 'Replying...' : 'Type a message...',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
              onChanged: _onTextChanged,
              minLines: 1,
              maxLines: 5,
            ),
          ),
          IconButton(icon: const Icon(Icons.attach_file, color: Colors.white70), onPressed: _pickFile),
          IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendText),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildTopBar(),
      body: Column(
        children: [
          // Watermark shadow frame header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Center(
              child: Text('CHAT — $currentRoom', style: const TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),

          // Messages
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 18, offset: const Offset(0, 8)),
                ],
                border: Border.all(color: Colors.white10),
              ),
              child: loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, i) => _buildMessageTile(messages[i]),
                        ),

                        // Typing indicator bottom-left
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: typingUsers.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    typingUsers.values.length == 1 ? 'typing...' : '${typingUsers.length} typing...',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
            ),
          ),

          // Emoji area
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

          // Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _buildInputArea(),
          )
        ],
      ),
    );
  }
}
