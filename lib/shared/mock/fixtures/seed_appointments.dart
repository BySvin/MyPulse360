import '../../../features/appointments/domain/entities/appointment.dart';
import '../mock_ids.dart';

List<Appointment> seedAppointments() {
  final now = DateTime.now();
  DateTime at(int dayOffset, int hour, int minute) {
    final d = now.add(Duration(days: dayOffset));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  return [
    // Sarah's upcoming appointment — surfaced on the dashboard banner.
    Appointment(
      id: 'appt-sarah-1',
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedDoctorId,
      clinicId: MockIds.defaultClinicId,
      scheduledAt: at(1, 14, 0),
      durationMinutes: 30,
      appointmentType: 'General Checkup',
      status: AppointmentStatus.confirmed,
      reasonForVisit: 'Regular checkup',
      roomLabel: 'Room 2',
    ),
    // Dr. Ahmed's queue today.
    Appointment(
      id: 'appt-today-1',
      patientId: MockIds.patient2Id,
      doctorId: MockIds.drAhmedDoctorId,
      clinicId: MockIds.defaultClinicId,
      scheduledAt: at(0, 9, 0),
      durationMinutes: 30,
      appointmentType: 'Follow-up',
      status: AppointmentStatus.completed,
      reasonForVisit: 'Hypertension follow-up',
      roomLabel: 'Room 1',
    ),
    Appointment(
      id: 'appt-today-2',
      patientId: MockIds.patient3Id,
      doctorId: MockIds.drAhmedDoctorId,
      clinicId: MockIds.defaultClinicId,
      scheduledAt: at(0, 10, 30),
      durationMinutes: 20,
      appointmentType: 'New Patient',
      status: AppointmentStatus.confirmed,
      reasonForVisit: 'General consultation',
      roomLabel: 'Room 1',
    ),
    Appointment(
      id: 'appt-today-3',
      patientId: MockIds.patient4Id,
      doctorId: MockIds.drAhmedDoctorId,
      clinicId: MockIds.defaultClinicId,
      scheduledAt: at(0, 11, 15),
      durationMinutes: 20,
      appointmentType: 'Follow-up',
      status: AppointmentStatus.scheduled,
      reasonForVisit: 'Asthma review',
      roomLabel: 'Room 1',
    ),
    Appointment(
      id: 'appt-today-4',
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedDoctorId,
      clinicId: MockIds.defaultClinicId,
      scheduledAt: at(0, 13, 30),
      durationMinutes: 30,
      appointmentType: 'Diabetes Follow-up',
      status: AppointmentStatus.scheduled,
      reasonForVisit: 'Blood sugar management',
      roomLabel: 'Room 2',
    ),
  ];
}
