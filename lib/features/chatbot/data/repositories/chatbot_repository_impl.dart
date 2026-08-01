import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chatbot_repository.dart';
import '../datasources/chatbot_datasource.dart';

class ChatbotRepositoryImpl implements ChatbotRepository {
  ChatbotRepositoryImpl(this._dataSource);

  final ChatbotDataSource _dataSource;

  @override
  ChatConversation getConversation(String patientId) => _dataSource.getConversation(patientId);

  @override
  Future<ChatMessage> sendMessage(String patientId, String text) =>
      _dataSource.sendMessage(patientId, text);
}
