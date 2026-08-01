import '../../../../shared/mock/mock_database.dart';
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
}
