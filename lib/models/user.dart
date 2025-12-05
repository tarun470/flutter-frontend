class User {
  final String id;
  final String username;
  final String? nickname;
  final String? profileImage;
  final bool isOnline;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.username,
    this.nickname,
    this.profileImage,
    this.isOnline = false,
    this.lastSeen,
  });

  // ------------------------------
  // ID PARSER (MongoDB ObjectId)
  // ------------------------------
  static String _parseId(dynamic field) {
    if (field == null) return '';

    if (field is String) return field;

    // MongoDB {"$oid": "..."} format
    if (field is Map && field.containsKey("\$oid")) {
      return field["\$oid"];
    }

    return field.toString(); // safest fallback
  }

  // ------------------------------
  // DATE PARSER (supports all MongoDB formats)
  // ------------------------------
  static DateTime? _parseDate(dynamic field) {
    if (field == null) return null;

    try {
      // Normal ISO date string
      if (field is String) return DateTime.parse(field);

      // MongoDB: {"$date": "2024-01-01"}
      if (field is Map && field['\$date'] != null) {
        final raw = field['\$date'];

        // MongoDB: {"$date": {"$numberLong": "1700000000000"}}
        if (raw is Map && raw['\$numberLong'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            int.parse(raw['\$numberLong']),
          );
        }

        // MongoDB ISO string inside $date
        if (raw is String) return DateTime.parse(raw);
      }
    } catch (_) {}

    return null;
  }

  // ------------------------------
  // FROM JSON
  // ------------------------------
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseId(json['_id'] ?? json['id']),
      username: json['username'] ?? '',
      nickname: json['nickname'],
      profileImage: json['profileImage'] ?? json['avatarUrl'],
      isOnline: json['isOnline'] ?? json['online'] ?? false,
      lastSeen: _parseDate(json['lastSeen'] ?? json['last_seen']),
    );
  }

  // ------------------------------
  // TO JSON
  // ------------------------------
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'nickname': nickname,
      'profileImage': profileImage,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  // ------------------------------
  // COPY-WITH (important for updating UI state)
  // ------------------------------
  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? profileImage,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      profileImage: profileImage ?? this.profileImage,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
