import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/data/db_failure.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../utils/chat_reply_engine.dart';
import 'chatbot_datasource.dart';

/// Live chatbot over the real backend. This is a rules-and-persistence layer,
/// not an LLM: replies come from the same [generateChatReply] engine the mock
/// uses, fed with the patient's real appointments and prescriptions. Persists
/// every message into `chat_messages` and touches the conversation's
/// `updated_at` so "resume most recent" works.
class SupabaseChatbotDataSource implements ChatbotDataSource {
  SupabaseChatbotDataSource(this._client);

  final SupabaseClient _client;

  DateTime _utc(Object? v) => DateTime.parse(v! as String).toUtc();

  ChatSender _sender(String label) =>
      label == 'user' ? ChatSender.user : ChatSender.assistant;

  ChatConversation _conversationFromRow(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> messageRows,
  ) =>
      ChatConversation(
        id: row['id'] as String,
        patientId: row['patient_id'] as String,
        updatedAt: _utc(row['updated_at']),
        messages: messageRows.map(_messageFromRow).toList(),
      );

  ChatMessage _messageFromRow(Map<String, dynamic> r) => ChatMessage(
        id: r['id'] as String,
        sender: _sender(r['sender'] as String),
        text: r['body'] as String,
        timestamp: _utc(r['sent_at']),
        quickReplies:
            List<String>.from(r['quick_replies'] as List? ?? const []),
      );

  Future<ChatConversation> _loadConversation(String id, String patientId) async {
    final row = await _client
        .from('chat_conversations')
        .select('*')
        .eq('id', id)
        .eq('patient_id', patientId)
        .single();
    final messages = await _client
        .from('chat_messages')
        .select('*')
        .eq('conversation_id', id)
        .order('seq');
    return _conversationFromRow(row, messages);
  }

  @override
  Future<List<ChatConversation>> getConversations(String patientId) async {
    try {
      final rows = await _client
          .from('chat_conversations')
          .select('*')
          .eq('patient_id', patientId)
          .order('updated_at', ascending: false);
      if (rows.isEmpty) return [];
      final ids = rows.map((r) => r['id'] as String).toList();
      final messages = await _client
          .from('chat_messages')
          .select('*')
          .inFilter('conversation_id', ids)
          .order('seq');
      return [
        for (final row in rows)
          _conversationFromRow(
            row,
            messages.where((m) => m['conversation_id'] == row['id']).toList(),
          ),
      ];
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<ChatConversation> getOrCreateActiveConversation(
    String patientId,
  ) async {
    try {
      final rows = await _client
          .from('chat_conversations')
          .select('*')
          .eq('patient_id', patientId)
          .order('updated_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return startNewConversation(patientId);
      return _loadConversation(rows.first['id'] as String, patientId);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<ChatConversation> startNewConversation(String patientId) async {
    try {
      final row = await _client
          .from('chat_conversations')
          .insert({'patient_id': patientId})
          .select()
          .single();
      return _conversationFromRow(row, const []);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String patientId,
    required String conversationId,
    required String text,
  }) async {
    try {
      await _client
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender': 'user',
            'body': text,
          })
          .select()
          .single();

      // Force the touch trigger so resume-most-recent jumps to this chat.
      await _client
          .from('chat_conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);

      final reply = await _generateReply(patientId, text);

      final replyRow = await _client
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender': 'assistant',
            'body': reply.text,
            'quick_replies': reply.quickReplies,
          })
          .select()
          .single();

      return _messageFromRow(replyRow);
    } catch (e) {
      throw mapPostgrestError(e);
    }
  }

  Future<ChatReply> _generateReply(String patientId, String text) async {
    final upcomingRows = await _client
        .from('appointments')
        .select('id, doctor_id, scheduled_at')
        .eq('patient_id', patientId)
        .neq('status', 'cancelled')
        .gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
        .order('scheduled_at');

    // Patients can't read the profiles table (RLS), so doctor names come from
    // the SECURITY DEFINER `doctor_directory()` helper instead.
    final Map<String, String> doctorNames = {};
    try {
      final directory = await _client.rpc('doctor_directory');
      for (final row in directory as List) {
        final m = Map<String, dynamic>.from(row as Map);
        if (m['id'] != null) doctorNames[m['id'] as String] = m['full_name'] as String;
      }
    } catch (_) {
      // Fall back to "your doctor" rather than failing the whole reply.
    }

    List<String> medications = const [];
    try {
      final ids = (await _client
              .from('prescriptions')
              .select('id')
              .eq('patient_id', patientId)
              .neq('status', 'expired'))
          .map((r) => r['id'] as String)
          .toList();
      if (ids.isNotEmpty) {
        final items = await _client
            .from('prescription_items')
            .select('medication_name, strength')
            .inFilter('prescription_id', ids);
        medications = [
          for (final r in items)
            '${r['medication_name']} ${r['strength']}',
        ];
      }
    } catch (_) {
      // Absent recent medications shouldn't block the appointment answer.
    }

    return generateChatReply(
      text: text,
      upcomingAppointments: [
        for (final r in upcomingRows)
          AppointmentContext(
            scheduledAt: _utc(r['scheduled_at']),
            doctorName: doctorNames[r['doctor_id']] ?? 'your doctor',
          ),
      ],
      activeMedications: medications,
    );
  }
}