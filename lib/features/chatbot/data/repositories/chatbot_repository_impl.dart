import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chatbot_repository.dart';
import '../datasources/chatbot_datasource.dart';

class ChatbotRepositoryImpl implements ChatbotRepository {
  ChatbotRepositoryImpl(this._dataSource);

  final ChatbotDataSource _dataSource;

  @override
  Future<List<ChatConversation>> getConversations(String patientId) =>
      _dataSource.getConversations(patientId);

  @override
  Future<ChatConversation> getOrCreateActiveConversation(String patientId) =>
      _dataSource.getOrCreateActiveConversation(patientId);

  @override
  Future<ChatConversation> startNewConversation(String patientId) =>
      _dataSource.startNewConversation(patientId);

  @override
  Future<ChatMessage> sendMessage({
    required String patientId,
    required String conversationId,
    required String text,
  }) =>
      _dataSource.sendMessage(
        patientId: patientId,
        conversationId: conversationId,
        text: text,
      );
}