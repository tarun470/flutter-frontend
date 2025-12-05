import '../models/message.dart';
import '../services/api_service.dart';
import '../utils/secure_storage.dart';

class MessageService {
  final SecureStorageService _storage = SecureStorageService();

  /// Fetch message history for a room safely
  Future<List<Message>> fetchHistory(String roomId) async {
    final token = await _storage.getToken();
    if (token == null) return [];

    try {
      final list = await ApiService.fetchMessages(roomId, token);

      // Convert MessageModel → Message
      return list.map((m) {
        return Message(
          id: m.id,
          senderId: "", // backend does not send senderId in MessageModel
          senderName: "",
          roomId: m.roomId,
          content: m.content,
          type: m.type,
          timestamp: DateTime.now(), // fallback since history API missing timestamp
          isDelivered: true,
          isSeen: false,
          isEdited: m.edited,
          fileName: m.fileName,
          reactions: {},
        );
      }).toList();
    } catch (e) {
      print("❌ MessageService.fetchHistory Exception: $e");
      return [];
    }
  }
}

