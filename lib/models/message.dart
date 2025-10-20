class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // handle both `senderId` and nested `sender._id`
    final senderField = json['senderId'] ??
        (json['sender'] is Map ? json['sender']['_id'] : json['sender']) ??
        '';

    // handle both timestamp and createdAt fields
    final timestampStr =
        json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String();

    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: senderField,
      content: json['content'] ?? '',
      timestamp: DateTime.tryParse(timestampStr) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'senderId': senderId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}
