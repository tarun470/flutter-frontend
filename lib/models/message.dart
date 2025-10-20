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
    String parseId(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Map && field.containsKey('\$oid')) return field['\$oid'];
      return '';
    }

    String parseDate(dynamic field) {
      try {
        if (field == null) return DateTime.now().toIso8601String();
        if (field is String) return field;
        if (field is Map && field['\$date'] != null) {
          if (field['\$date'] is Map && field['\$date']['\$numberLong'] != null) {
            return DateTime.fromMillisecondsSinceEpoch(
                    int.parse(field['\$date']['\$numberLong']))
                .toIso8601String();
          }
          return DateTime.parse(field['\$date']).toIso8601String();
        }
      } catch (_) {}
      return DateTime.now().toIso8601String();
    }

    final id = parseId(json['_id'] ?? json['id']);
    final senderField = parseId(json['senderId'] ??
        (json['sender'] is Map ? json['sender']['_id'] : json['sender']));
    final timestampStr = parseDate(json['timestamp'] ?? json['createdAt']);

    return Message(
      id: id,
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
