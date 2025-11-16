// lib/models/message.dart
class Message {
  final String id;
  final String senderId;
  final String senderName; // nickname display
  final String roomId;
  final String content;
  final String type; // 'text' | 'image' | 'file' | 'reply'
  final DateTime timestamp;
  bool isDelivered;
  bool isSeen;
  bool isEdited;
  String? replyToMessageId;
  Map<String, int>? reactions; // { "❤️": 2, "😂": 1 }
  List<String>? deliveredTo; // optional
  List<String>? seenBy; // optional

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.roomId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isDelivered = false,
    this.isSeen = false,
    this.isEdited = false,
    this.replyToMessageId,
    this.reactions,
    this.deliveredTo,
    this.seenBy,
  });

  static String _parseId(dynamic field) {
    if (field == null) return '';
    if (field is String) return field;
    if (field is Map && field.containsKey('\$oid')) return field['\$oid'];
    return '';
  }

  static DateTime _parseDate(dynamic field) {
    try {
      if (field == null) return DateTime.now();
      if (field is String) return DateTime.parse(field);
      if (field is Map && field['\$date'] != null) {
        final date = field['\$date'];
        if (date is Map && date['\$numberLong'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(int.parse(date['\$date']['\$numberLong']));
        }
        return DateTime.parse(date);
      }
    } catch (_) {}
    return DateTime.now();
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _parseId(json['_id'] ?? json['id']),
      senderId: _parseId(json['sender'] ?? json['senderId'] ?? json['from']),
      senderName: json['senderName'] ?? (json['sender'] is Map ? (json['sender']['username'] ?? '') : json['senderName'] ?? ''),
      roomId: json['room'] ?? json['roomId'] ?? 'global',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      timestamp: _parseDate(json['timestamp'] ?? json['createdAt']),
      isDelivered: (json['status'] == 'delivered') || (json['isDelivered'] ?? false),
      isSeen: (json['status'] == 'seen') || (json['isSeen'] ?? false),
      isEdited: json['isEdited'] ?? false,
      replyToMessageId: _parseId(json['replyTo']),
      reactions: json['reactions'] != null ? Map<String, int>.from(json['reactions']) : {},
      deliveredTo: json['deliveredTo'] != null ? List<String>.from(json['deliveredTo']) : [],
      seenBy: json['seenBy'] != null ? List<String>.from(json['seenBy']) : [],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'senderId': senderId,
        'senderName': senderName,
        'roomId': roomId,
        'content': content,
        'type': type,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'isDelivered': isDelivered,
        'isSeen': isSeen,
        'isEdited': isEdited,
        'replyTo': replyToMessageId,
        'reactions': reactions,
        'deliveredTo': deliveredTo,
        'seenBy': seenBy,
      };
}
