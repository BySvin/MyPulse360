import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

/// Backend contract for the health assistant. Conversations are first-class
/// rows (a patient can have many over time) and every call is async so the
/// Supabase implementation is a straight passthrough.
abstract class ChatbotDataSource {
  /// All of the patient's conversations, most recently updated first.
  Future<List<ChatConversation>> getConversations(String patientId);

  /// The conversation to resume. When the patient has none yet, this creates
  /// and returns an empty one (the greeter state).
  Future<ChatConversation> getOrCreateActiveConversation(String patientId);

  /// Starts a fresh conversation row separate from the existing history.
  Future<ChatConversation> startNewConversation(String patientId);

  /// Appends the user message and the generated assistant reply to
  /// [conversationId] and returns the assistant reply (with its quick replies
  /// and optional one-shot action).
  Future<ChatMessage> sendMessage({
    required String patientId,
    required String conversationId,
    required String text,
  });
}