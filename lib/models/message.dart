class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;

  final String roomId;
  final String content;
  final String type; // text | image | file | system

  final DateTime timestamp;

  bool isDelivered;
  bool isSeen;
  bool isEdited;

  String? replyToMessageId;
  Map<String, int> reactions;

  List<String> deliveredTo;
  List<String> seenBy;

  final String? fileUrl;
  final String? fileName;

  final bool deletedForEveryone;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.roomId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.reactions,
    required this.deliveredTo,
    required this.seenBy,
    this.senderAvatar,
    this.replyToMessageId,
    this.fileUrl,
    this.fileName,
    this.deletedForEveryone = false,
    this.isDelivered = false,
    this.isSeen = false,
    this.isEdited = false,
  });

  // ------------------------------------------------
  // HELPERS
  // ------------------------------------------------
  static String _parseId(dynamic value) {
    if (value == null) return "";
    if (value is String) return value;

    if (value is Map && value.containsKey("\$oid")) {
      return value["\$oid"];
    }

    return value.toString();
  }

  static DateTime _parseDate(dynamic value) {
    try {
      if (value is String) return DateTime.parse(value);

      if (value is Map && value["\$date"] != null) {
        final d = value["\$date"];
        if (d is String) return DateTime.parse(d);

        if (d is Map && d["\$numberLong"] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            int.parse(d["\$numberLong"]),
          );
        }
      }
    } catch (_) {}

    return DateTime.now();
  }

  // ------------------------------------------------
  // FROM JSON
  // ------------------------------------------------
  factory Message.fromJson(Map<String, dynamic> json) {
    final senderMap = json["sender"] is Map ? json["sender"] as Map : null;

    return Message(
      id: _parseId(json["_id"]),
      senderId: senderMap != null ? _parseId(senderMap["_id"]) : "",
      senderName: senderMap?["nickname"] ?? senderMap?["username"] ?? "",
      senderAvatar: senderMap?["avatar"],

      roomId: json["roomId"] ?? "global",
      content: json["content"] ?? "",
      type: json["type"] ?? "text",

      timestamp: _parseDate(json["createdAt"]),

      fileUrl: json["fileUrl"],
      fileName: json["fileName"],

      replyToMessageId: json["replyTo"] != null
          ? _parseId(json["replyTo"])
          : null,

      reactions: json["reactions"] != null
          ? Map<String, int>.from(json["reactions"])
          : {},

      deliveredTo: json["deliveredTo"] != null
          ? List<String>.from(json["deliveredTo"].map((e) => e.toString()))
          : [],

      seenBy: json["seenBy"] != null
          ? List<String>.from(json["seenBy"].map((e) => e.toString()))
          : [],

      isDelivered: json["isDelivered"] ?? false,
      isSeen: json["isSeen"] ?? false,
      isEdited: json["edited"] ?? false,

      deletedForEveryone: json["deletedForEveryone"] ?? false,
    );
  }

  // ------------------------------------------------
  // TO JSON
  // ------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "senderId": senderId,
      "senderName": senderName,
      "senderAvatar": senderAvatar,

      "roomId": roomId,
      "content": content,
      "type": type,
      "timestamp": timestamp.toIso8601String(),

      "fileUrl": fileUrl,
      "fileName": fileName,

      "isDelivered": isDelivered,
      "isSeen": isSeen,
      "isEdited": isEdited,

      "replyTo": replyToMessageId,
      "reactions": reactions,
      "deliveredTo": deliveredTo,
      "seenBy": seenBy,

      "deletedForEveryone": deletedForEveryone,
    };
  }
}
