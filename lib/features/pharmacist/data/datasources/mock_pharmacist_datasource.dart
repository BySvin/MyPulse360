import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../domain/entities/pharmacist_profile.dart';
import 'pharmacist_datasource.dart';

class MockPharmacistDataSource implements PharmacistDataSource {
  MockPharmacistDataSource(this._db);

  final MockDatabase _db;

  @override
  PharmacistProfile? getProfile(String pharmacistId) {
    for (final p in _db.pharmacists) {
      if (p.id == pharmacistId) return p;
    }
    return null;
  }

  @override
  List<Prescription> getQueue(String pharmacyId) {
    // "Pending verification" = freshly issued and not yet dispensed — an
    // ongoing active prescription from weeks ago (already verified at the
    // time) shouldn't reappear in the counter queue.
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final list = _db.prescriptions
        .where((p) => p.status == PrescriptionStatus.active && p.issuedDate.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.issuedDate.compareTo(b.issuedDate));
    return list;
  }

  @override
  List<Consultation> getAwaitingPrescription() {
    final prescribedConsultationIds = _db.prescriptions
        .map((p) => p.consultationId)
        .whereType<String>()
        .toSet();
    return _db.consultations
        .where((c) => c.status == ConsultationStatus.completed && !prescribedConsultationIds.contains(c.id))
        .toList();
  }

  @override
  List<Appointment> getTodaysAppointments() {
    final now = DateTime.now();
    final list = _db.appointments
        .where((a) =>
            a.scheduledAt.year == now.year &&
            a.scheduledAt.month == now.month &&
            a.scheduledAt.day == now.day &&
            a.status != AppointmentStatus.cancelled)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  @override
  Future<void> logTemperature(String appointmentId, String patientId, String doctorId, double temperature) async {
    Consultation? existing;
    for (final c in _db.consultations) {
      if (c.appointmentId == appointmentId) {
        existing = c;
        break;
      }
    }
    
    existing ??= Consultation(
        id: generateId(),
        appointmentId: appointmentId,
        patientId: patientId,
        doctorId: doctorId,
        status: ConsultationStatus.inProgress,
      );
    
    final updatedVitals = (existing.vitals).copyWith(
      temperatureCelsius: temperature,
    );
    
    final updated = Consultation(
      id: existing.id,
      appointmentId: existing.appointmentId,
      patientId: existing.patientId,
      doctorId: existing.doctorId,
      status: existing.status,
      vitals: updatedVitals,
      diagnosis: existing.diagnosis,
      notes: existing.notes,
      recommendations: existing.recommendations,
    );
    
    _db.upsertConsultation(updated);
  }
}
