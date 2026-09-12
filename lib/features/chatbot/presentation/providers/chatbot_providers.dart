import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env/env.dart';
import '../../../../shared/data/supabase_providers.dart';
import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/chatbot_datasource.dart';
import '../../data/datasources/mock_chatbot_datasource.dart';
import '../../data/datasources/supabase_chatbot_datasource.dart';
import '../../data/repositories/chatbot_repository_impl.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chatbot_repository.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  final ChatbotDataSource dataSource = Env.isMockMode
      ? MockChatbotDataSource(ref.watch(mockDatabaseProvider))
      : SupabaseChatbotDataSource(ref.watch(supabaseClientProvider));
  return ChatbotRepositoryImpl(dataSource);
});

/// Bumped after any mutating call so the previous-chats list refetches.
final chatRevisionProvider = StateProvider<int>((ref) => 0);

final chatConversationsProvider =
    FutureProvider.family<List<ChatConversation>, String>((ref, patientId) async {
  ref.watch(chatRevisionProvider);
  return ref.watch(chatbotRepositoryProvider).getConversations(patientId);
});