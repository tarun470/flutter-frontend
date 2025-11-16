import '../models/message.dart';
import 'api_service.dart';
import '../utils/secure_storage.dart';

class MessageService {
  final SecureStorageService _storage = SecureStorageService();

  Future<List<Message>> fetchHistory(String roomId) async {
    final token = await _storage.getToken();
    if (token == null) return [];
    final List<dynamic> raw = await ApiService.fetchMessages(roomId, token);
    return raw.map((j) => Message.fromJson(Map<String, dynamic>.from(j))).toList();
  }
}
