import 'package:equatable/equatable.dart';

enum LeaveStatus {
  pending,
  approved,
  denied;

  String get label => switch (this) {
        LeaveStatus.pending => 'Pending',
        LeaveStatus.approved => 'Approved',
        LeaveStatus.denied => 'Denied',
      };
}

class LeaveRequest extends Equatable {
  const LeaveRequest({
    required this.id,
    required this.staffId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.decidedBy,
    this.decidedAt,
  });

  final String id;
  final String staffId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final DateTime requestedAt;
  final String? decidedBy;
  final DateTime? decidedAt;

  bool coversDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  LeaveRequest copyWith({LeaveStatus? status, String? decidedBy, DateTime? decidedAt}) {
    return LeaveRequest(
      id: id,
      staffId: staffId,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: status ?? this.status,
      requestedAt: requestedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      decidedAt: decidedAt ?? this.decidedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, staffId, startDate, endDate, reason, status, requestedAt, decidedBy, decidedAt];
}
