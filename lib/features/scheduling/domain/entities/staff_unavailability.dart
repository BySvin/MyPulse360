import 'package:equatable/equatable.dart';

/// A single day a staff member has marked themselves unavailable — a
/// lighter-weight, no-approval-needed counterpart to [LeaveRequest], used
/// as an input to shift conflict checks and the auto-fill suggestion.
class StaffUnavailability extends Equatable {
  const StaffUnavailability({
    required this.id,
    required this.staffId,
    required this.date,
    this.reason,
  });

  final String id;
  final String staffId;
  final DateTime date;
  final String? reason;

  bool isSameDay(DateTime other) =>
      date.year == other.year && date.month == other.month && date.day == other.day;

  @override
  List<Object?> get props => [id, staffId, date, reason];
}
