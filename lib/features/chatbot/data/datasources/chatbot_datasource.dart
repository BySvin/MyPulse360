import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

abstract class ChatbotDataSource {
  ChatConversation getConversation(String patientId);

  Future<ChatMessage> sendMessage(String patientId, String text);
}
