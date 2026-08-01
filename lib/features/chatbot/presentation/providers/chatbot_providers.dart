import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/mock/mock_database.dart';
import '../../data/datasources/mock_chatbot_datasource.dart';
import '../../data/repositories/chatbot_repository_impl.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chatbot_repository.dart';

final chatbotRepositoryProvider = Provider<ChatbotRepository>((ref) {
  return ChatbotRepositoryImpl(MockChatbotDataSource(ref.watch(mockDatabaseProvider)));
});

final chatRevisionProvider = StateProvider<int>((ref) => 0);

final chatConversationProvider = Provider.family<ChatConversation, String>((ref, patientId) {
  ref.watch(chatRevisionProvider);
  return ref.watch(chatbotRepositoryProvider).getConversation(patientId);
});
