import '../../../features/chatbot/domain/entities/chat_conversation.dart';
import '../../../features/chatbot/domain/entities/chat_message.dart';
import '../mock_ids.dart';

ChatConversation seedChat() {
  final now = DateTime.now();
  return ChatConversation(
    id: 'chat-sarah',
    patientId: MockIds.sarahPatientId,
    updatedAt: now,
    messages: [
      ChatMessage(
        id: 'msg-welcome',
        sender: ChatSender.assistant,
        text: "Hi Sarah! I'm your Health Assistant. Ask me about your "
            'medications, appointments, or symptoms — or tap a suggestion below.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        quickReplies: const [
          'When is my next appointment?',
          'What medications am I taking?',
          'I have a headache',
        ],
      ),
    ],
  );
}
