import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/theme_mode_provider.dart';
import '../../../../config/router/route_paths.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/date_formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chatbot_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/quick_reply_chips.dart';
import '../widgets/typing_indicator.dart';

/// P8 — Health Assistant chat, with typing state, quick replies, and real
/// conversation history (resumed on open, "New chat" starts a fresh thread).
class HealthAssistantPage extends ConsumerStatefulWidget {
  const HealthAssistantPage({super.key});

  @override
  ConsumerState<HealthAssistantPage> createState() => _HealthAssistantPageState();
}

class _HealthAssistantPageState extends ConsumerState<HealthAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _started = false;
  bool _loading = true;
  bool _typing = false;
  List<ChatConversation> _conversations = const [];
  ChatConversation? _active;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init(String patientId) async {
    try {
      final resume =
          await ref.read(chatbotRepositoryProvider).getOrCreateActiveConversation(patientId);
      final list = await ref.read(chatbotRepositoryProvider).getConversations(patientId);
      if (!mounted) return;
      setState(() {
        _conversations = list;
        ChatConversation active = resume;
        if (list.isNotEmpty) {
          active = list.firstWhere((c) => c.id == resume.id, orElse: () => list.first);
        }
        _active = active;
        _loading = false;
      });
      _scrollToBottom();
    } on Exception {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshConversations(String patientId) async {
    try {
      final list = await ref.read(chatbotRepositoryProvider).getConversations(patientId);
      if (!mounted) return;
      setState(() => _conversations = list);
    } on Exception {
      // The drawer can still show the last-known list.
    }
  }

  Future<void> _newChat(String patientId) async {
    try {
      final created =
          await ref.read(chatbotRepositoryProvider).startNewConversation(patientId);
      if (!mounted) return;
      setState(() {
        _conversations = [created, ..._conversations.where((c) => c.id != created.id)];
        _active = created;
      });
      ref.read(chatRevisionProvider.notifier).state++;
      if (context.mounted) Navigator.pop(context);
      _scrollToBottom();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a new chat. Please try again.')),
      );
    }
  }

  void _openConversation(ChatConversation conversation) {
    setState(() => _active = conversation);
    _scrollToBottom();
  }

  Future<void> _send(String patientId, String text) async {
    final active = _active;
    if (active == null || text.trim().isEmpty) return;
    _controller.clear();
    final optimistic = ChatMessage(
      id: '',
      sender: ChatSender.user,
      text: text.trim(),
      timestamp: DateTime.now(),
    );
    setState(() {
      _typing = true;
      _active = active.copyWith(messages: [...active.messages, optimistic]);
    });
    _scrollToBottom();

    final reply = await ref.read(chatbotRepositoryProvider).sendMessage(
          patientId: patientId,
          conversationId: active.id,
          text: text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _typing = false;
      _active = _active?.copyWith(messages: [...?_active?.messages, reply]);
    });
    ref.read(chatRevisionProvider.notifier).state++;
    _refreshConversations(patientId);
    _scrollToBottom();

    if (reply.actionType == 'booking_success') {
      _showSuccessOverlay();
    } else if (reply.actionType == 'enable_dark_mode') {
      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    } else if (reply.actionType == 'enable_light_mode') {
      ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
    } else if (reply.actionType == 'open_settings') {
      context.go(RoutePaths.patientProfile);
    }
  }

  String _conversationTitle(ChatConversation c) {
    for (final m in c.messages) {
      if (m.sender == ChatSender.user) {
        final t = m.text.trim();
        return t.length > 32 ? '${t.substring(0, 32)}…' : (t.isEmpty ? 'New chat' : t);
      }
    }
    return c.messages.isEmpty ? 'New chat' : 'Chat with Health Assistant';
  }

  String _conversationSubtitle(ChatConversation c) {
    final anchor = c.updatedAt ??
        (c.messages.isEmpty ? DateTime.now() : c.messages.last.timestamp);
    return DateFormatters.relative(anchor);
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

  void _showSuccessOverlay() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return const Center(
          child: _SuccessAnimation(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _init(user.id));
    }

    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEBF4FF),
                    Color(0xFFF3E7FF),
                    Color(0xFFFFF0F5),
                    Color(0xFFE8F4FF),
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    final messages = _active?.messages ?? const <ChatMessage>[];
    final hasMessages = messages.isNotEmpty;
    final lastQuickReplies =
        messages.isNotEmpty && messages.last.sender == ChatSender.assistant && !_typing
            ? messages.last.quickReplies
            : const <String>[];

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Previous Chats',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: _conversations.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No previous chats yet.'),
                      )
                    : ListView(
                        children: [
                          for (final c in _conversations)
                            ListTile(
                              leading: Icon(
                                _active?.id == c.id
                                    ? Icons.chat_bubble
                                    : Icons.chat_bubble_outline,
                              ),
                              title: Text(
                                _conversationTitle(c),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(_conversationSubtitle(c)),
                              selected: _active?.id == c.id,
                              onTap: () {
                                _openConversation(c);
                                Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: () => _newChat(user.id),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('New chat'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEBF4FF), // light blue top left
                  Color(0xFFF3E7FF), // light purple top right
                  Color(0xFFFFF0F5), // pinkish bottom right
                  Color(0xFFE8F4FF), // light blue bottom left
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Background Orbs
          Positioned(
            top: 150,
            left: -80,
            child: _buildOrb(
              size: 250,
              colors: const [Color(0xFFFFC0E1), Color(0xFFD8B4FE)],
            ),
          ),
          Positioned(
            bottom: -50,
            right: -80,
            child: _buildOrb(
              size: 300,
              colors: const [Color(0xFFFFC0E1), Color(0xFFB4C6FE)],
            ),
          ),
          Positioned(
            top: -20,
            right: -40,
            child: _buildOrb(
              size: 150,
              colors: const [Color(0xFFB4C6FE), Color(0xFFD8B4FE)],
            ),
          ),

          // Glass overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (context) => _buildIconButton(Icons.menu, context, () {
                          Scaffold.of(context).openDrawer();
                        }),
                      ),
                      _buildIconButton(Icons.settings, context, () {
                        context.go(RoutePaths.patientProfile);
                      }),
                    ],
                  ),
                ),

                if (!hasMessages) ...[
                  const SizedBox(height: 24),

                  // Greeting text
                  Text(
                    'Hello, ${user.fullName.split(' ').first}!\nHow can I help you today?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF333333), // dark text
                      height: 1.3,
                    ),
                  ),

                  const Expanded(
                    child: Center(
                      child: _CentralOrb(),
                    ),
                  ),

                  // Quick Action Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildActionChip(Icons.calendar_today_outlined, 'Book appointment', () => _send(user.id, 'Book appointment'))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildActionChip(Icons.medication_outlined, 'My prescriptions', () => _send(user.id, 'Check my prescriptions'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildActionChip(Icons.monitor_heart_outlined, 'Health dashboard', () => _send(user.id, 'View health dashboard'))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildActionChip(Icons.lightbulb_outline, 'Daily health tips', () => _send(user.id, 'Give me daily health tips'))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ] else ...[
                  // Chat Messages
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
                ],

                // Bottom Input Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _newChat(user.id),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8E4FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Color(0xFF7B61FF)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: 'Ask me anything...',
                              hintStyle: TextStyle(color: Colors.black54),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (text) => _send(user.id, text),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _send(user.id, _controller.text),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7B61FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mic, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, BuildContext context, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, color: const Color(0xFF7B61FF), size: 20),
      ),
    );
  }

  Widget _buildOrb({required double size, required List<Color> colors}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF7B61FF), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CentralOrb extends StatefulWidget {
  const _CentralOrb();

  @override
  State<_CentralOrb> createState() => _CentralOrbState();
}

class _CentralOrbState extends State<_CentralOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double blink = (_controller.value > 0.45 && _controller.value < 0.55) ? 0.1 : 1.0;

        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Faint outer circle (glass ring)
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4 * _pulseAnimation.value),
                      width: 2,
                    ),
                  ),
                ),
                // Central glowing orb
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFB06AB3), // purple
                        Color(0xFF4568DC), // blue
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4568DC).withValues(alpha: 0.5 * _pulseAnimation.value),
                        blurRadius: 40 * _pulseAnimation.value,
                        spreadRadius: 10 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                ),
                // Eyes
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 24 * blink,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 12,
                      height: 24 * blink,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuccessAnimation extends StatefulWidget {
  const _SuccessAnimation();
  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _controller.forward().then((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 80),
                  SizedBox(height: 16),
                  Text(
                    'Booked!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}