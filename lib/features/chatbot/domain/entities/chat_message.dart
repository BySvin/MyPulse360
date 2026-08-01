import 'package:equatable/equatable.dart';

enum ChatSender { user, assistant }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.quickReplies = const [],
  });

  final String id;
  final ChatSender sender;
  final String text;
  final DateTime timestamp;
  final List<String> quickReplies;

  @override
  List<Object?> get props => [id, sender, text, timestamp, quickReplies];
}
