import 'package:equatable/equatable.dart';

enum AppointmentStatus {
  scheduled,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rescheduled;

  String get label => switch (this) {
        AppointmentStatus.scheduled => 'Scheduled',
        AppointmentStatus.confirmed => 'Confirmed',
        AppointmentStatus.inProgress => 'In Progress',
        AppointmentStatus.completed => 'Completed',
        AppointmentStatus.cancelled => 'Cancelled',
        AppointmentStatus.rescheduled => 'Rescheduled',
      };
}

class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.clinicId,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.appointmentType,
    required this.status,
    this.reasonForVisit,
    this.roomLabel,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final String clinicId;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String appointmentType;
  final AppointmentStatus status;
  final String? reasonForVisit;
  final String? roomLabel;

  Appointment copyWith({AppointmentStatus? status, DateTime? scheduledAt}) {
    return Appointment(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      clinicId: clinicId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes,
      appointmentType: appointmentType,
      status: status ?? this.status,
      reasonForVisit: reasonForVisit,
      roomLabel: roomLabel,
    );
  }

  @override
  List<Object?> get props => [
        id,
        patientId,
        doctorId,
        clinicId,
        scheduledAt,
        durationMinutes,
        appointmentType,
        status,
        reasonForVisit,
        roomLabel,
      ];
}
