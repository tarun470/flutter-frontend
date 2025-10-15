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
    return Message(
      id: json['_id'],
      senderId: json['sender']['_id'] ?? json['sender'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
