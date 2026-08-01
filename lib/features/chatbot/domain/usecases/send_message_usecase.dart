import '../entities/chat_message.dart';
import '../repositories/chatbot_repository.dart';

class SendMessageUseCase {
  SendMessageUseCase(this._repository);

  final ChatbotRepository _repository;

  Future<ChatMessage> call(String patientId, String text) => _repository.sendMessage(patientId, text);
}
