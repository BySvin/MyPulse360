import 'package:flutter/material.dart';

import '../../../../config/theme/app_radii.dart';
import '../../../../config/theme/app_theme.dart';
import '../../domain/entities/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = message.sender == ChatSender.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? colors.patientAccent : colors.surfaceMuted,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadii.card),
            topRight: const Radius.circular(AppRadii.card),
            bottomLeft: Radius.circular(isUser ? AppRadii.card : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppRadii.card),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: isUser ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
