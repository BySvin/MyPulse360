import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/entities/doctor_profile.dart';
import 'doctor_datasource.dart';

class MockDoctorDataSource implements DoctorDataSource {
  MockDoctorDataSource(this._db);

  final MockDatabase _db;

  @override
  DoctorProfile? getProfile(String doctorId) {
    for (final d in _db.doctors) {
      if (d.id == doctorId) return d;
    }
    return null;
  }

  @override
  List<Appointment> getTodaysQueue(String doctorId) {
    final now = DateTime.now();
    final list = _db.appointments
        .where((a) =>
            a.doctorId == doctorId &&
            a.scheduledAt.year == now.year &&
            a.scheduledAt.month == now.month &&
            a.scheduledAt.day == now.day &&
            a.status != AppointmentStatus.cancelled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  Consultation startOrGetConsultation(String appointmentId, String patientId, String doctorId) {
    for (final c in _db.consultations) {
      if (c.appointmentId == appointmentId) return c;
    }
    final consultation = Consultation(
      id: generateId(),
      appointmentId: appointmentId,
      patientId: patientId,
      doctorId: doctorId,
      status: ConsultationStatus.inProgress,
    );
    _db.upsertConsultation(consultation);
    return consultation;
  }

  @override
  Future<Consultation> submitConsultation(Consultation consultation) async {
    await simulateLatency();
    final completed = Consultation(
      id: consultation.id,
      appointmentId: consultation.appointmentId,
      patientId: consultation.patientId,
      doctorId: consultation.doctorId,
      status: ConsultationStatus.completed,
      vitals: consultation.vitals,
      diagnosis: consultation.diagnosis,
      notes: consultation.notes,
      recommendations: consultation.recommendations,
    );
    _db.upsertConsultation(completed);

    final apptIndex = _db.appointments.indexWhere((a) => a.id == consultation.appointmentId);
    if (apptIndex != -1) {
      _db.appointments[apptIndex] = _db.appointments[apptIndex].copyWith(status: AppointmentStatus.completed);
    }
    return completed;
  }

  @override
  List<Consultation> getPatientHistory(String patientId) {
    DateTime? scheduledAtFor(String appointmentId) {
      for (final a in _db.appointments) {
        if (a.id == appointmentId) return a.scheduledAt;
      }
      return null;
    }

    final list = _db.consultations.where((c) => c.patientId == patientId).toList()
      ..sort((a, b) {
        final aDate = scheduledAtFor(a.appointmentId) ?? DateTime(0);
        final bDate = scheduledAtFor(b.appointmentId) ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
    return list;
  }
}
