class User {
  final String id;
  final String username;
  final String? nickname;
  final String? profileImage;
  final bool? isOnline;
  final DateTime? lastSeen;

  User({
    required this.id,
    required this.username,
    this.nickname,
    this.profileImage,
    this.isOnline,
    this.lastSeen,
  });

  static String _parseId(dynamic field) {
    if (field == null) return '';
    if (field is String) return field;
    if (field is Map && field.containsKey("\$oid")) return field["\$oid"];
    return '';
  }

  static DateTime? _parseDate(dynamic field) {
    if (field == null) return null;
    try {
      if (field is String) return DateTime.parse(field);
      if (field is Map && field['\$date'] != null) {
        final dateField = field['\$date'];
        if (dateField is Map && dateField['\$numberLong'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(int.parse(dateField['\$numberLong']));
        }
        return DateTime.parse(dateField);
      }
    } catch (_) {}
    return null;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseId(json['id'] ?? json['_id']),
      username: json['username'] ?? '',
      nickname: json['nickname'],
      profileImage: json['profileImage'],
      isOnline: json['isOnline'],
      lastSeen: _parseDate(json['lastSeen']),
    );
  }
}
