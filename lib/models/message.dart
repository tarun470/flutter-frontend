// lib/models/message.dart

class Message {
  final String id;
  final String senderId;
  final String senderName; // nickname display
  final String roomId;
  final String content;
  final String type; // text | image | file | reply
  final DateTime timestamp;

  bool isDelivered;
  bool isSeen;
  bool isEdited;

  String? replyToMessageId;
  Map<String, int>? reactions;

  List<String>? deliveredTo;
  List<String>? seenBy;

  // NEW FIELD - required for fixing your build error
  final String? fileName;

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
    this.fileName,
  });

  // ---------------------------------------------
  // SAFE PARSERS
  // ---------------------------------------------
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

      if (field is Map) {
        final date = field['\$date'];

        if (date is Map && date['\$numberLong'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            int.parse(date['\$numberLong']),
          );
        }

        if (date is String) return DateTime.parse(date);
      }
    } catch (_) {}
    return DateTime.now();
  }

  // ---------------------------------------------
  // FROM JSON
  // ---------------------------------------------
  factory Message.fromJson(Map<String, dynamic> json) {
    final delivered = json['deliveredTo'];
    final seen = json['seenBy'];

    return Message(
      id: _parseId(json['_id'] ?? json['id']),
      senderId: _parseId(json['sender'] ?? json['senderId'] ?? json['from']),
      senderName: json['senderName'] ??
          (json['sender'] is Map ? (json['sender']['username'] ?? '') : ''),

      roomId: json['room'] ?? json['roomId'] ?? 'global',
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      timestamp: _parseDate(json['timestamp'] ?? json['createdAt']),

      isDelivered: json['isDelivered'] ?? json['status'] == 'delivered',
      isSeen: json['isSeen'] ?? json['status'] == 'seen',
      isEdited: json['isEdited'] ?? false,

      replyToMessageId: _parseId(json['replyTo']),

      reactions: json['reactions'] != null
          ? Map<String, int>.from(json['reactions'])
          : {},

      // FIX: Convert List<dynamic> → List<String>
      deliveredTo: delivered != null
          ? List<String>.from(delivered.map((e) => e.toString()))
          : [],

      seenBy: seen != null
          ? List<String>.from(seen.map((e) => e.toString()))
          : [],

      // FIX: Add fileName support
      fileName: json['fileName'],
    );
  }

  // ---------------------------------------------
  // TO JSON
  // ---------------------------------------------
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
        'fileName': fileName, // Added
      };
}
