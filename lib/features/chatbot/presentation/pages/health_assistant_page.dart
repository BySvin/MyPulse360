import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/presentation/widgets/large_title_app_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/chatbot_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/quick_reply_chips.dart';
import '../widgets/typing_indicator.dart';

/// P8 — Health Assistant chat, with typing state and quick replies.
class HealthAssistantPage extends ConsumerStatefulWidget {
  const HealthAssistantPage({super.key});

  @override
  ConsumerState<HealthAssistantPage> createState() => _HealthAssistantPageState();
}

class _HealthAssistantPageState extends ConsumerState<HealthAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _typing = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String patientId, String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() => _typing = true);
    ref.read(chatRevisionProvider.notifier).state++;
    _scrollToBottom();
    await ref.read(chatbotRepositoryProvider).sendMessage(patientId, text);
    if (!mounted) return;
    setState(() => _typing = false);
    ref.read(chatRevisionProvider.notifier).state++;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final conversation = ref.watch(chatConversationProvider(user.id));
    final messages = conversation.messages;
    final lastQuickReplies = messages.isNotEmpty && messages.last.sender.name == 'assistant' && !_typing
        ? messages.last.quickReplies
        : const <String>[];

    return Scaffold(
      appBar: const LargeTitleAppBar(title: 'Assistant', showBack: false),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                for (final m in messages) ChatBubble(message: m),
                if (_typing) const TypingIndicator(),
                if (lastQuickReplies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  QuickReplyChips(
                    replies: lastQuickReplies,
                    onSelect: (r) => _send(user.id, r),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask a question…',
                        filled: true,
                        fillColor: colors.surfaceMuted,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(99),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (text) => _send(user.id, text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: colors.patientAccent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _send(user.id, _controller.text),
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
