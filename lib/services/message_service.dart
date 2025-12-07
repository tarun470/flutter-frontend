import '../models/message.dart';
import '../services/api_service.dart';
import '../utils/secure_storage.dart';

class MessageService {
  final SecureStorageService _storage = SecureStorageService();

  Future<List<Message>> fetchHistory(String roomId) async {
    final token = await _storage.getToken();
    if (token == null) return [];

    try {
      final list = await ApiService.fetchMessages(roomId, token);

      return list.map((m) {
        return Message(
          id: m.id,
          senderId: "",
          senderName: "",
          roomId: m.roomId,
          content: m.content,
          type: m.type,
          timestamp: DateTime.now(),

          // REQUIRED FIELDS 👇
          reactions: {},
          deliveredTo: [],
          seenBy: [],

          fileUrl: m.fileUrl,
          fileName: m.fileName,
          replyToMessageId: null,
        );
      }).toList();
    } catch (e) {
      print("❌ MessageService.fetchHistory Error: $e");
      return [];
    }
  }
}
