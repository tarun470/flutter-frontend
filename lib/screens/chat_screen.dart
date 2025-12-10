import 'package:flutter/foundation.dart' show kIsWeb;
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
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();

  // SERVICES
  final SocketService socketService = SocketService();
  final SecureStorageService storage = SecureStorageService();
  final MessageService msgService = MessageService();

  // USER INFO
  String? userId;
  String? username;
  String? token;

  // CHAT STATE
  List<Message> messages = [];
  bool showEmoji = false;
  bool loadingHistory = true;

  String currentRoom = "general";
  int onlineCount = 0;

  String? replyToMessageId;

  /// userId -> username (for typing text)
  Map<String, String> typingUsers = {};

  /// userId -> full user map from socket (online list)
  Map<String, dynamic> onlineUsersMap = {};

  /// userId -> lastSeen DateTime
  Map<String, DateTime> lastSeenMap = {};

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
  // INIT USER + LOAD HISTORY
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

    final hist = await msgService.fetchHistory(currentRoom);
    messages = hist;

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
    socketService.connect(
      token!,
      onConnect: () {
        socketService.joinRoom(currentRoom);

        // New message from server
        socketService.onMessage = (msg) {
          // Avoid duplicates
          if (!messages.any((m) => m.id == msg.id)) {
            setState(() => messages.add(msg));
            _scrollBottom();
          }
        };

        // Typing users
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

        // Online users map
        socketService.onOnlineUsers = (count, map) {
          setState(() {
            onlineCount = count;
            onlineUsersMap = map;
          });
        };

        // Delivery status ✔
        socketService.onMessageDelivered = (m) {
          final i = messages.indexWhere((x) => x.id == m.id);
          if (i != -1) {
            setState(() {
              messages[i].isDelivered = true;
              messages[i].deliveredTo = m.deliveredTo;
            });
          }
        };

        // Seen status ✔✔
        socketService.onMessageSeen = (m) {
          final i = messages.indexWhere((x) => x.id == m.id);
          if (i != -1) {
            setState(() {
              messages[i].isSeen = true;
              messages[i].seenBy = m.seenBy;
            });
          }
        };

        // Last seen updates
        socketService.onLastSeenUpdated = (payload) {
          if (payload is Map<String, dynamic>) {
            // Case 1: { userId, lastSeen }
            if (payload["userId"] != null && payload["lastSeen"] != null) {
              final uid = payload["userId"].toString();
              final rawTs = payload["lastSeen"].toString();
              try {
                lastSeenMap[uid] = DateTime.parse(rawTs).toLocal();
              } catch (_) {}
            }
            // Case 2: { users: { userId: { lastSeen: ... } } }
            else if (payload["users"] is Map) {
              final users = Map<String, dynamic>.from(payload["users"]);
              users.forEach((uid, data) {
                final rawTs = data["lastSeen"];
                if (rawTs != null) {
                  try {
                    lastSeenMap[uid] =
                        DateTime.parse(rawTs.toString()).toLocal();
                  } catch (_) {}
                }
              });
            }
            setState(() {});
          }
        };
      },
    );
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
  // SEND TEXT MESSAGE (NO DUPLICATES)
  // -------------------------------------------------------------
  Future<void> _sendText() async {
    final text = messageCtrl.text.trim();
    if (text.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // 🔥 Do NOT add to messages list here (no local duplicate)
    socketService.sendMessage(
      text,
      roomId: currentRoom,
      senderName: username!,
      tempId: tempId,
      replyTo: replyToMessageId,
    );

    // Clear input
    messageCtrl.clear();
    replyToMessageId = null;
    showEmoji = false;

    // Stop typing event
    socketService.sendTyping(currentRoom, userId!, username!, false);
  }

  // -------------------------------------------------------------
  // SEND IMAGE  (mobile only)
  // -------------------------------------------------------------
  Future<void> _sendImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image upload is not supported on Web yet.")),
      );
      return;
    }

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

      if (uploaded == null || uploaded.fileUrl == null) return;

      // Do NOT add temp message, let socket push real one (if backend emits)
      socketService.sendFile(
        uploaded.fileUrl!,
        uploaded.fileName ?? picked.name,
        roomId: currentRoom,
        senderName: username!,
      );
    } catch (e) {
      debugPrint("Image send error: $e");
    }
  }

  // -------------------------------------------------------------
  // SEND FILE (mobile only)
  // -------------------------------------------------------------
  Future<void> _sendFile() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File upload is not supported on Web yet.")),
      );
      return;
    }

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

      if (uploaded == null || uploaded.fileUrl == null) return;

      socketService.sendFile(
        uploaded.fileUrl!,
        uploaded.fileName ?? name,
        roomId: currentRoom,
        senderName: username!,
      );
    } catch (e) {
      debugPrint("Upload error: $e");
    }
  }

  // -------------------------------------------------------------
  // ONLINE + LAST ACTIVE HELPERS
  // -------------------------------------------------------------
  bool _isUserOnline(String uid) {
    if (onlineUsersMap.isEmpty) return false;
    return onlineUsersMap.containsKey(uid);
  }

  String _lastActiveText(String uid) {
    if (_isUserOnline(uid)) return "online";

    final ts = lastSeenMap[uid];
    if (ts == null) return "last active: unknown";

    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inMinutes < 1) return "last active just now";
    if (diff.inMinutes < 60) return "last active ${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "last active ${diff.inHours} h ago";
    if (diff.inDays == 1) return "last active yesterday";
    return "last active ${diff.inDays} days ago";
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
  // MESSAGE BUBBLE (Neon + Avatar + Last Active)
  // -------------------------------------------------------------
  Widget _bubble(Message m) {
    final bool isMe = m.senderId == userId;
    final DateTime localTs = m.timestamp.toLocal();
    final String time = DateFormat('hh:mm a').format(localTs);

    final bool isOnline = _isUserOnline(m.senderId);
    final String lastActive = _lastActiveText(m.senderId);

    final Color meStart = const Color(0xFF38BDF8); // neon cyan
    final Color meEnd = const Color(0xFF6366F1); // neon indigo
    final Color otherStart = const Color(0xFF111827);
    final Color otherEnd = const Color(0xFF020617);

    final Gradient bubbleGradient = isMe
        ? LinearGradient(
            colors: [meStart, meEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [otherStart, otherEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final BoxShadow neonShadow = BoxShadow(
      color: isMe
          ? meEnd.withOpacity(0.5)
          : Colors.blueAccent.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );

    final String initials =
        m.senderName.isNotEmpty ? m.senderName[0].toUpperCase() : "?";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: bubbleGradient,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [neonShadow],
              border: Border.all(
                color: isMe
                    ? Colors.white.withOpacity(0.15)
                    : Colors.blueAccent.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // ---------- HEADER: avatar + username + status ----------
                  if (!isMe)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black.withOpacity(0.4),
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.senderName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Online dot
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              lastActive,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  if (!isMe) const SizedBox(height: 6),

                  // ---------- CONTENT ----------
                  if (m.type == "image")
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        m.fileUrl ?? m.content,
                        width: 220,
                        height: 220,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (m.type == "file")
                    Row(
                      children: [
                        const Icon(Icons.insert_drive_file,
                            color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.fileName ?? "file",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      m.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),

                  const SizedBox(height: 4),

                  // ---------- TIME + TICKS ----------
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      _tick(m),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
      decoration: const BoxDecoration(
        color: Color(0xFF020617),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 0.6),
        ),
      ),
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
                if (userId == null || username == null) return;
                socketService.sendTyping(
                  currentRoom,
                  userId!,
                  username!,
                  txt.isNotEmpty,
                );
              },
              decoration: const InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),

          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.white70),
            onPressed: _sendFile,
          ),
          IconButton(
            icon: const Icon(Icons.image, color: Colors.greenAccent),
            onPressed: _sendImage,
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
  // BUILD UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 4,
        shadowColor: Colors.blueAccent.withOpacity(0.4),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "GENERAL",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "$onlineCount online",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        // 🔥 LOGOUT BUTTON WITH CONFIRMATION
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF0A0F1F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text(
                    "Logout?",
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    "Are you sure you want to logout?",
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white70),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                socketService.disconnect();
                // Make sure your SecureStorageService has this method
                await storage.clearAll();

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
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
