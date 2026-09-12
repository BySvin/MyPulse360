import 'package:equatable/equatable.dart';

class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.clockInAt,
    this.clockOutAt,
  });

  final String id;
  final String staffId;
  final DateTime clockInAt;
  final DateTime? clockOutAt;

  bool get isOpen => clockOutAt == null;

  Duration? get workedDuration => clockOutAt?.difference(clockInAt);

  AttendanceRecord copyWith({DateTime? clockOutAt}) {
    return AttendanceRecord(
      id: id,
      staffId: staffId,
      clockInAt: clockInAt,
      clockOutAt: clockOutAt ?? this.clockOutAt,
    );
  }

  @override
  List<Object?> get props => [id, staffId, clockInAt, clockOutAt];
}
