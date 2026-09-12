import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';

abstract class ChatbotRepository {
  Future<List<ChatConversation>> getConversations(String patientId);

  Future<ChatConversation> getOrCreateActiveConversation(String patientId);

  Future<ChatConversation> startNewConversation(String patientId);

  Future<ChatMessage> sendMessage({
    required String patientId,
    required String conversationId,
    required String text,
  });
}