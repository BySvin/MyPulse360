import 'package:equatable/equatable.dart';

import 'chat_message.dart';

class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.patientId,
    required this.messages,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final List<ChatMessage> messages;

  /// Recency marker for "active chat" selection and the previous-chats list.
  final DateTime? updatedAt;

  ChatConversation copyWith({List<ChatMessage>? messages, DateTime? updatedAt}) {
    return ChatConversation(
      id: id,
      patientId: patientId,
      messages: messages ?? this.messages,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, patientId, messages, updatedAt];
}
