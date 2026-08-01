import 'package:equatable/equatable.dart';

import 'chat_message.dart';

class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.patientId,
    required this.messages,
  });

  final String id;
  final String patientId;
  final List<ChatMessage> messages;

  ChatConversation copyWith({List<ChatMessage>? messages}) {
    return ChatConversation(id: id, patientId: patientId, messages: messages ?? this.messages);
  }

  @override
  List<Object?> get props => [id, patientId, messages];
}
