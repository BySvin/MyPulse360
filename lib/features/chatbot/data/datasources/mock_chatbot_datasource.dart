import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../utils/chat_reply_engine.dart';
import 'chatbot_datasource.dart';

/// In-memory counterpart to [SupabaseChatbotDataSource]. Persists to the
/// shared [MockDatabase] store and answers through the same pure
/// [generateChatReply] engine, so behaviour matches the real backend.
class MockChatbotDataSource implements ChatbotDataSource {
  MockChatbotDataSource(this._db);

  final MockDatabase _db;

  @override
  Future<List<ChatConversation>> getConversations(String patientId) async {
    final list = _db.chatConversations.where((c) => c.patientId == patientId).toList();
    list.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return list;
  }

  @override
  Future<ChatConversation> getOrCreateActiveConversation(String patientId) async {
    final existing = _db.chatConversations.where((c) => c.patientId == patientId).toList();
    if (existing.isEmpty) return _newConversation(patientId);
    existing.sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    return existing.first;
  }

  @override
  Future<ChatConversation> startNewConversation(String patientId) async {
    return _newConversation(patientId);
  }

  ChatConversation _newConversation(String patientId) {
    final convo = ChatConversation(
      id: generateId(),
      patientId: patientId,
      messages: const [],
      updatedAt: DateTime.now(),
    );
    _db.chatConversations.add(convo);
    return convo;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String patientId,
    required String conversationId,
    required String text,
  }) async {
    final now = DateTime.now();
    final userMessage = ChatMessage(
      id: generateId(),
      sender: ChatSender.user,
      text: text,
      timestamp: now,
    );
    _replaceConversation(
      _find(conversationId).copyWith(messages: [..._find(conversationId).messages, userMessage], updatedAt: now),
    );

    await simulateLatency();

    final reply = _replyFor(patientId, text, DateTime.now());
    final refreshed = _find(conversationId);
    _replaceConversation(
      refreshed.copyWith(messages: [...refreshed.messages, reply], updatedAt: reply.timestamp),
    );
    return reply;
  }

  ChatMessage _replyFor(String patientId, String text, DateTime now) {
    final upcoming = _db.appointments
        .where((a) => a.patientId == patientId && a.scheduledAt.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final active = _db.prescriptions
        .where((p) => p.patientId == patientId && p.status != PrescriptionStatus.expired)
        .toList();
    final medications = active
        .expand((p) => p.items.map((i) => '${i.medicationName} ${i.strength}'))
        .toList();

    final generated = generateChatReply(
      text: text,
      upcomingAppointments: [
        for (final a in upcoming)
          AppointmentContext(
            scheduledAt: a.scheduledAt,
            doctorName: _db.userById(a.doctorId)?.fullName ?? 'your doctor',
          ),
      ],
      activeMedications: medications,
    );

    return ChatMessage(
      id: generateId(),
      sender: ChatSender.assistant,
      text: generated.text,
      timestamp: now,
      quickReplies: generated.quickReplies,
      actionType: generated.actionType,
    );
  }

  ChatConversation _find(String id) => _db.chatConversations.firstWhere((c) => c.id == id);

  void _replaceConversation(ChatConversation updated) {
    final i = _db.chatConversations.indexWhere((c) => c.id == updated.id);
    if (i == -1) {
      _db.chatConversations.add(updated);
    } else {
      _db.chatConversations[i] = updated;
    }
  }
}