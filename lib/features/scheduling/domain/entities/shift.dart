import 'package:equatable/equatable.dart';

enum ShiftStatus {
  scheduled,
  completed,
  missed,
  cancelled;

  String get label => switch (this) {
        ShiftStatus.scheduled => 'Scheduled',
        ShiftStatus.completed => 'Completed',
        ShiftStatus.missed => 'Missed',
        ShiftStatus.cancelled => 'Cancelled',
      };
}

class Shift extends Equatable {
  const Shift({
    required this.id,
    required this.staffId,
    required this.clinicId,
    required this.start,
    required this.end,
    required this.status,
    this.notes,
  });

  final String id;
  final String staffId;
  final String clinicId;
  final DateTime start;
  final DateTime end;
  final ShiftStatus status;
  final String? notes;

  Duration get duration => end.difference(start);

  bool overlaps(DateTime otherStart, DateTime otherEnd) =>
      start.isBefore(otherEnd) && otherStart.isBefore(end);

  Shift copyWith({ShiftStatus? status}) {
    return Shift(
      id: id,
      staffId: staffId,
      clinicId: clinicId,
      start: start,
      end: end,
      status: status ?? this.status,
      notes: notes,
    );
  }

  @override
  List<Object?> get props => [id, staffId, clinicId, start, end, status, notes];
}
