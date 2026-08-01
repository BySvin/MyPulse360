import '../../domain/entities/appointment.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../datasources/appointments_datasource.dart';

class AppointmentsRepositoryImpl implements AppointmentsRepository {
  AppointmentsRepositoryImpl(this._dataSource);

  final AppointmentsDataSource _dataSource;

  @override
  List<Appointment> getForPatient(String patientId) => _dataSource.getForPatient(patientId);

  @override
  List<Appointment> getForDoctor(String doctorId) => _dataSource.getForDoctor(doctorId);

  @override
  Appointment? getNextUpcoming(String patientId) => _dataSource.getNextUpcoming(patientId);

  @override
  List<TimeSlot> getAvailableSlots({required String doctorId, required DateTime date}) =>
      _dataSource.getAvailableSlots(doctorId: doctorId, date: date);

  @override
  Future<Appointment> book({
    required String patientId,
    required String doctorId,
    required DateTime scheduledAt,
    required String appointmentType,
    String? reasonForVisit,
  }) =>
      _dataSource.book(
        patientId: patientId,
        doctorId: doctorId,
        scheduledAt: scheduledAt,
        appointmentType: appointmentType,
        reasonForVisit: reasonForVisit,
      );

  @override
  Future<Appointment> updateStatus(String appointmentId, AppointmentStatus status) =>
      _dataSource.updateStatus(appointmentId, status);

  @override
  Future<Appointment> reschedule(String appointmentId, DateTime newTime) =>
      _dataSource.reschedule(appointmentId, newTime);
}
