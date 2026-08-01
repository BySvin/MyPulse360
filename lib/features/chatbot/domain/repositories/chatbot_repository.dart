import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';

abstract class ChatbotRepository {
  ChatConversation getConversation(String patientId);

  Future<ChatMessage> sendMessage(String patientId, String text);
}
