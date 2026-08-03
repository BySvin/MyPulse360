import 'package:equatable/equatable.dart';

/// Logged wherever the spec calls for an SMS — there's no real SMS gateway
/// configured in this environment, so this is an honest in-app stand-in
/// ("here's what would have been texted") rather than a fake success state.
class StaffNotification extends Equatable {
  const StaffNotification({
    required this.id,
    required this.staffId,
    required this.message,
    required this.sentAt,
  });

  final String id;
  final String staffId;
  final String message;
  final DateTime sentAt;

  @override
  List<Object?> get props => [id, staffId, message, sentAt];
}
