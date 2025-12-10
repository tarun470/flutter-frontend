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
  final TextEditingController messageCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();

  final SocketService socketService = SocketService();
  final SecureStorageService storage = SecureStorageService();
  final MessageService msgService = MessageService();

  String? userId;     // stored but not used for alignment
  String? username;   // USED for message ownership
  String? token;

  List<Message> messages = [];
  bool showEmoji = false;
  bool loadingHistory = true;

  String currentRoom = "general";
  int onlineCount = 0;

  String? replyToMessageId;

  Map<String, String> typingUsers = {}; // nickname-based
  Map<String, dynamic> onlineUsersMap = {};
  Map<String, DateTime> lastSeenMap = {}; // nickname-based

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
    username = await storage.getUsername(); // nickname used as identity

    if (token == null || username == null) {
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

        socketService.onMessage = (msg) {
          // prevent duplicates
          if (!messages.any((m) => m.id == msg.id)) {
            setState(() => messages.add(msg));
            _scrollBottom();
          }
        };

        // TYPING indicator (nickname-based)
        socketService.onTyping = (uid, isTyping, uname) {
          if (uname == username) return;
          setState(() {
            if (isTyping) {
              typingUsers[uname ?? "User"] = uname ?? "User";
            } else {
              typingUsers.remove(uname);
            }
          });
        };

        // Online users list (contains username)
        socketService.onOnlineUsers = (count, map) {
          setState(() {
            onlineCount = count;
            onlineUsersMap = map;
          });
        };

        // Delivery ✔
        socketService.onMessageDelivered = (m) {
          final i = messages.indexWhere((x) => x.id == m.id);
          if (i != -1) {
            setState(() {
              messages[i].isDelivered = true;
              messages[i].deliveredTo = m.deliveredTo;
            });
          }
        };

        // Seen ✔✔
        socketService.onMessageSeen = (m) {
          final i = messages.indexWhere((x) => x.id == m.id);
          if (i != -1) {
            setState(() {
              messages[i].isSeen = true;
              messages[i].seenBy = m.seenBy;
            });
          }
        };

        // Last seen map now uses NICKNAME
        socketService.onLastSeenUpdated = (payload) {
          if (payload is Map<String, dynamic>) {
            if (payload["users"] is Map) {
              final users = Map<String, dynamic>.from(payload["users"]);
              users.forEach((uid, data) {
                final name = data["username"]?.toString();
                final raw = data["lastSeen"]?.toString();
                if (name != null && raw != null) {
                  try {
                    lastSeenMap[name] = DateTime.parse(raw).toLocal();
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
  // HELPERS
  // -------------------------------------------------------------
  void _scrollBottom({int delay = 80}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (!scrollCtrl.hasClients) return;
      scrollCtrl.animateTo(
        scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isUserOnline(String? name) {
    if (name == null || onlineUsersMap.isEmpty) return false;
    return onlineUsersMap.values.any(
      (u) => u["username"]?.toString() == name,
    );
  }

  String _lastActiveText(String? name) {
    if (name == null) return "unknown";

    if (_isUserOnline(name)) return "online";

    final ts = lastSeenMap[name];
    if (ts == null) return "last active: unknown";

    final diff = DateTime.now().difference(ts);

    if (diff.inMinutes < 1) return "last active just now";
    if (diff.inMinutes < 60) return "last active ${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "last active ${diff.inHours} hr ago";
    if (diff.inDays == 1) return "last active yesterday";
    return "last active ${diff.inDays} days ago";
  }

  Future<void> _sendText() async {
    final text = messageCtrl.text.trim();
    if (text.isEmpty) return;

    socketService.sendMessage(
      text,
      roomId: currentRoom,
      senderName: username!,
      tempId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    messageCtrl.clear();
    socketService.sendTyping(currentRoom, userId!, username!, false);
  }

  Future<void> _sendImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image upload not supported on Web.")),
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

      if (uploaded?.fileUrl != null) {
        socketService.sendFile(
          uploaded!.fileUrl!,
          uploaded.fileName ?? picked.name,
          roomId: currentRoom,
          senderName: username!,
        );
      }
    } catch (_) {}
  }

  Future<void> _sendFile() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File upload not supported on Web.")),
      );
      return;
    }

    try {
      final res = await FilePicker.platform.pickFiles();
      if (res == null) return;

      final uploaded = await ApiService.uploadFile(
        res.files.single.path!,
        "file",
        token: token,
        filename: res.files.single.name,
      );

      if (uploaded?.fileUrl != null) {
        socketService.sendFile(
          uploaded!.fileUrl!,
          uploaded.fileName ?? res.files.single.name,
          roomId: currentRoom,
          senderName: username!,
        );
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // UI WIDGETS
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

  Widget _tick(Message m) {
    if (m.senderName != username) return const SizedBox();

    if (!m.isDelivered) {
      return const Icon(Icons.check, size: 16, color: Colors.white38);
    }
    if (!m.isSeen) {
      return const Icon(Icons.done_all, size: 16, color: Colors.white70);
    }
    return const Icon(Icons.done_all,
        size: 16, color: Colors.lightBlueAccent);
  }

  // -------------------------------------------------------------
  // MESSAGE BUBBLE (nickname-based)
  // -------------------------------------------------------------
  Widget _bubble(Message m) {
    final bool isMe = m.senderName == username;

    final DateTime ts = m.timestamp.toLocal();
    final String time = DateFormat('hh:mm a').format(ts);

    final bool isOnline = _isUserOnline(m.senderName);
    final String lastActive = _lastActiveText(m.senderName);

    final String initials =
        m.senderName.isNotEmpty ? m.senderName[0].toUpperCase() : "?";

    final Gradient bubbleGradient = isMe
        ? const LinearGradient(
            colors: [Color(0xFF38BDF8), Color(0xFF6366F1)])
        : const LinearGradient(
            colors: [Color(0xFF111827), Color(0xFF020617)],
          );

    final BoxShadow neonShadow = BoxShadow(
      color:
          isMe ? Colors.cyanAccent.withOpacity(0.4) : Colors.blueAccent.withOpacity(0.3),
      blurRadius: 18,
      offset: const Offset(0, 6),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
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
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.black54,
                          child: Text(
                            initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Row(
                              children: [
                                Text(
                                  m.senderName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              ],
                            ),
                            Text(
                              lastActive,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        )
                      ],
                    ),

                  if (!isMe) const SizedBox(height: 6),

                  // MESSAGE CONTENT
                  if (m.type == "image")
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        m.fileUrl ?? m.content,
                        width: 230,
                        height: 230,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (m.type == "file")
                    Row(
                      children: [
                        const Icon(Icons.insert_drive_file,
                            color: Colors.white70),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.fileName ?? "File",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ],
                    )
                  else
                    Text(
                      m.content,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 15),
                    ),

                  const SizedBox(height: 3),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10),
                      ),
                      const SizedBox(width: 5),
                      _tick(m),
                    ],
                  )
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
          top: BorderSide(color: Colors.blueGrey, width: 0.4),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon:
                Icon(showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined),
            color: Colors.white70,
            onPressed: () => setState(() => showEmoji = !showEmoji),
          ),

          Expanded(
            child: TextField(
              controller: messageCtrl,
              style: const TextStyle(color: Colors.white),
              onChanged: (text) {
                if (username == null) return;
                socketService.sendTyping(
                  currentRoom,
                  userId!,
                  username!,
                  text.isNotEmpty,
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
              onPressed: _sendFile),
          IconButton(
              icon: const Icon(Icons.image, color: Colors.greenAccent),
              onPressed: _sendImage),
          IconButton(
              icon: const Icon(Icons.send, color: Colors.cyanAccent),
              onPressed: _sendText),
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
        elevation: 3,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "GENERAL",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .5),
            ),
            Text(
              "$onlineCount online",
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            )
          ],
        ),

        // Logout with confirmation
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF0A0F1F),
                  title: const Text("Logout?", style: TextStyle(color: Colors.white)),
                  content: const Text("Do you really want to logout?",
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.white70))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Logout",
                            style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );

              if (confirm == true) {
                socketService.disconnect();
                await storage.clearAll();

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          )
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollCtrl,
                    padding:
                        const EdgeInsets.only(bottom: 70, top: 8),
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
