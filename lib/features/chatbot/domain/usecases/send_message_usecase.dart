import '../entities/chat_message.dart';
import '../repositories/chatbot_repository.dart';

class SendMessageUseCase {
  SendMessageUseCase(this._repository);

  final ChatbotRepository _repository;

  Future<ChatMessage> call({
    required String patientId,
    required String conversationId,
    required String text,
  }) =>
      _repository.sendMessage(
        patientId: patientId,
        conversationId: conversationId,
        text: text,
      );
}