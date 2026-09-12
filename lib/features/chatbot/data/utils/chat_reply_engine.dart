import '../../../../shared/utils/date_formatters.dart';

/// The appointment data the reply engine needs, pre-resolved by the caller's
/// backend so the engine itself stays network-free.
class AppointmentContext {
  const AppointmentContext({required this.scheduledAt, required this.doctorName});

  final DateTime scheduledAt;
  final String doctorName;
}

/// A generated assistant reply, still neutral about where it gets persisted.
class ChatReply {
  const ChatReply({
    required this.text,
    this.quickReplies = const [],
    this.actionType,
  });

  final String text;
  final List<String> quickReplies;

  /// Drives a one-shot UI action on the client (booking-success overlay,
  /// theme switch, settings navigation) — never persisted.
  final String? actionType;
}

/// The raw text of a user message plus the patient's live appointment /
/// medication state becomes a canned reply. `upcomingAppointments` is expected
/// sorted soonest-first; only the first (next) one is shown. This keeps the
/// keyword rules identical between the mock backend and Supabase — the two
/// datasources just feed different context.
ChatReply generateChatReply({
  required String text,
  required List<AppointmentContext> upcomingAppointments,
  required List<String> activeMedications,
}) {
  final lower = text.toLowerCase();

  if (lower.contains('tomorrow morning') || lower.contains('next week')) {
    return const ChatReply(
      text: 'Great! Your appointment has been successfully booked.',
      actionType: 'booking_success',
    );
  } else if (lower.contains('book') && lower.contains('appointment')) {
    return const ChatReply(
      text: 'When would you like to book your appointment for, and with which doctor?',
      quickReplies: ['Tomorrow morning', 'Next week'],
    );
  } else if (lower.contains('appointment')) {
    if (upcomingAppointments.isEmpty) {
      return const ChatReply(
        text:
            "You don't have any upcoming appointments. Want to book one from the Appointments tab?",
      );
    }
    final next = upcomingAppointments.first;
    return ChatReply(
      text:
          'Your next appointment is with ${next.doctorName} on '
          '${DateFormatters.full(next.scheduledAt)} at ${DateFormatters.time(next.scheduledAt)}.',
    );
  } else if (lower.contains('medication') ||
      lower.contains('prescription') ||
      lower.contains('rx')) {
    if (activeMedications.isEmpty) {
      return const ChatReply(
        text: "You don't have any active prescriptions right now.",
      );
    }
    return ChatReply(
      text: 'Your current medications: ${activeMedications.join(', ')}.',
      quickReplies: const ['Any side effects to watch for?'],
    );
  } else if (lower.contains('headache') ||
      lower.contains('pain') ||
      lower.contains('symptom') ||
      lower.contains('fever')) {
    return const ChatReply(
      text:
          "I'm sorry you're not feeling well. For persistent or severe symptoms, please book an "
          'appointment so your doctor can take a look. In the meantime, rest and stay hydrated.',
      quickReplies: ['Book an appointment'],
    );
  } else if (lower.contains('thank')) {
    return const ChatReply(
      text: "You're welcome! Let me know if there's anything else I can help with.",
    );
  } else if (lower.contains('dark mode') || lower.contains('dark theme')) {
    return const ChatReply(
      text: 'I have enabled dark mode for you!',
      actionType: 'enable_dark_mode',
    );
  } else if (lower.contains('light mode') || lower.contains('light theme')) {
    return const ChatReply(
      text: 'I have switched back to light mode!',
      actionType: 'enable_light_mode',
    );
  } else if (lower.contains('setting') || lower.contains('profile')) {
    return const ChatReply(
      text: 'I can help you navigate to your settings and profile page.',
      actionType: 'open_settings',
    );
  } else {
    return const ChatReply(
      text:
          "I can help with questions about your appointments, medications, or general symptoms. "
          'You can also ask me to change settings, like "Turn on dark mode". '
          'What would you like to know?',
      quickReplies: ['When is my next appointment?', 'Turn on dark mode', 'Open settings'],
    );
  }
}