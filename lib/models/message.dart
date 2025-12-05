class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String roomId;
  final String content;
  final String type; // text | image | file | reply
  final DateTime timestamp;

  bool isDelivered;
  bool isSeen;
  bool isEdited;

  String? replyToMessageId;
  Map<String, int>? reactions;

  List<String> deliveredTo;
  List<String> seenBy;

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
    List<String>? deliveredTo,
    List<String>? seenBy,
    this.fileName,
  })  : deliveredTo = deliveredTo ?? [],
        seenBy = seenBy ?? [];

  // ------------------------------
  // PARSERS
  // ------------------------------

  static String _parseId(dynamic field) {
    if (field == null) return '';
    if (field is String) return field;

    // MongoDB {"$oid": "..."}
    if (field is Map && field.containsKey('\$oid')) {
      return field['\$oid'];
    }

    // Node may send object → convert to string safely
    return field.toString();
  }

  static DateTime _parseDate(dynamic field) {
    try {
      if (field == null) return DateTime.now();

      if (field is String) return DateTime.parse(field);

      // MongoDB {"$date": {"$numberLong": "1234"}}
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

  // ------------------------------
  // FROM JSON
  // ------------------------------

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: _parseId(json['_id'] ?? json['id']),
      senderId: _parseId(json['sender'] ?? json['senderId'] ?? json['from']),
      senderName: json['senderName'] ??
          (json['sender'] is Map ? json['sender']['username'] ?? '' : ''),

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

      deliveredTo: json['deliveredTo'] != null
          ? List<String>.from(json['deliveredTo'].map((e) => e.toString()))
          : [],

      seenBy: json['seenBy'] != null
          ? List<String>.from(json['seenBy'].map((e) => e.toString()))
          : [],

      fileName: json['fileName'],
    );
  }

  // ------------------------------
  // TO JSON
  // ------------------------------

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'senderId': senderId,
      'senderName': senderName,
      'roomId': roomId,
      'content': content,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isDelivered': isDelivered,
      'isSeen': isSeen,
      'isEdited': isEdited,
      'replyTo': replyToMessageId,
      'reactions': reactions,
      'deliveredTo': deliveredTo,
      'seenBy': seenBy,
      'fileName': fileName,
    };
  }
}
