class User {
  final String id;
  final String username;
  final String nickname;
  final String? avatar;
  final String? bio;

  final bool isOnline;
  final DateTime? lastSeen;

  final bool allowReadReceipts;
  final bool allowLastSeen;
  final bool suspended;

  final List<String> blockedUsers;

  User({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.allowReadReceipts = true,
    this.allowLastSeen = true,
    this.suspended = false,
    this.blockedUsers = const [],
  });

  // ---------------------------------------------------------
  // ID PARSER - handles "_id", "id", {"$oid": "..."}
  // ---------------------------------------------------------
  static String _parseId(dynamic value) {
    if (value == null) return "";

    if (value is String) return value;

    if (value is Map && value.containsKey("\$oid")) {
      return value["\$oid"];
    }

    return value.toString();
  }

  // ---------------------------------------------------------
  // DATE PARSER - handles string, {"$date": ...}, {"$numberLong": ...}
  // ---------------------------------------------------------
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    try {
      if (value is String) return DateTime.parse(value);

      if (value is Map && value.containsKey("\$date")) {
        final dateField = value["\$date"];

        // case: {"$date": {"$numberLong": "1700000000000"}}
        if (dateField is Map && dateField.containsKey("\$numberLong")) {
          return DateTime.fromMillisecondsSinceEpoch(
            int.parse(dateField["\$numberLong"]),
          );
        }

        // case: {"$date": "2024-01-01T12:00:00Z"}
        if (dateField is String) return DateTime.parse(dateField);
      }
    } catch (_) {}

    return null;
  }

  // ---------------------------------------------------------
  // FROM JSON
  // ---------------------------------------------------------
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseId(json["_id"] ?? json["id"]),
      username: json["username"] ?? "",
      nickname: json["nickname"] ?? json["username"] ?? "",
      avatar: json["avatar"],
      bio: json["bio"],

      isOnline: json["isOnline"] ?? false,
      lastSeen: _parseDate(json["lastSeen"]),

      allowReadReceipts: json["allowReadReceipts"] ?? true,
      allowLastSeen: json["allowLastSeen"] ?? true,
      suspended: json["suspended"] ?? false,

      blockedUsers: (json["blockedUsers"] as List<dynamic>? ?? [])
          .map((u) => _parseId(u))
          .toList(),
    );
  }

  // ---------------------------------------------------------
  // TO JSON
  // ---------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "username": username,
      "nickname": nickname,
      "avatar": avatar,
      "bio": bio,
      "isOnline": isOnline,
      "lastSeen": lastSeen?.toIso8601String(),
      "allowReadReceipts": allowReadReceipts,
      "allowLastSeen": allowLastSeen,
      "suspended": suspended,
      "blockedUsers": blockedUsers,
    };
  }

  // ---------------------------------------------------------
  // COPY-WITH (useful for UI updates)
  // ---------------------------------------------------------
  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? avatar,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    bool? allowReadReceipts,
    bool? allowLastSeen,
    bool? suspended,
    List<String>? blockedUsers,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      allowReadReceipts: allowReadReceipts ?? this.allowReadReceipts,
      allowLastSeen: allowLastSeen ?? this.allowLastSeen,
      suspended: suspended ?? this.suspended,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}
