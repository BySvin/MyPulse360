import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/drug_interaction.dart';
import '../../domain/entities/prescription.dart';
import 'prescriptions_datasource.dart';

/// Small canned interaction table — enough to exercise the "live
/// interaction check" UI in the doctor's e-prescription flow without a
/// real drug database.
const _knownInteractions = [
  DrugInteraction(
    medicationA: 'warfarin',
    medicationB: 'aspirin',
    severity: InteractionSeverity.severe,
    description: 'Combined use significantly increases bleeding risk.',
  ),
  DrugInteraction(
    medicationA: 'lisinopril',
    medicationB: 'ibuprofen',
    severity: InteractionSeverity.moderate,
    description: 'NSAIDs may reduce the blood-pressure-lowering effect and stress the kidneys.',
  ),
  DrugInteraction(
    medicationA: 'metformin',
    medicationB: 'contrast dye',
    severity: InteractionSeverity.severe,
    description: 'Risk of lactic acidosis; hold metformin around contrast imaging.',
  ),
  DrugInteraction(
    medicationA: 'atorvastatin',
    medicationB: 'clarithromycin',
    severity: InteractionSeverity.moderate,
    description: 'Increases statin levels, raising risk of muscle toxicity.',
  ),
];

class MockPrescriptionsDataSource implements PrescriptionsDataSource {
  MockPrescriptionsDataSource(this._db);

  final MockDatabase _db;

  @override
  List<Prescription> getForPatient(String patientId) {
    final list = _db.prescriptions.where((p) => p.patientId == patientId).toList()
      ..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
    return list;
  }

  @override
  List<Prescription> getPendingVerification() {
    // Scanned/external prescriptions never queue for pharmacist
    // verification — no in-app consultation or pharmacist wrote them.
    return _db.prescriptions
        .where((p) => p.status == PrescriptionStatus.active && p.source == PrescriptionSource.inApp)
        .toList()
      ..sort((a, b) => b.issuedDate.compareTo(a.issuedDate));
  }

  @override
  Future<Prescription> create(Prescription prescription) async {
    await simulateLatency();
    final withId = prescription.id.isEmpty
        ? Prescription(
            id: generateId(),
            patientId: prescription.patientId,
            doctorId: prescription.doctorId,
            issuedDate: prescription.issuedDate,
            expiryDate: prescription.expiryDate,
            status: prescription.status,
            items: prescription.items,
            source: prescription.source,
            consultationId: prescription.consultationId,
            externalDoctorName: prescription.externalDoctorName,
          )
        : prescription;
    _db.prescriptions.add(withId);
    return withId;
  }

  @override
  Future<Prescription> updateStatus(String prescriptionId, PrescriptionStatus status) async {
    await simulateLatency();
    final i = _db.prescriptions.indexWhere((p) => p.id == prescriptionId);
    if (i == -1) throw StateError('Prescription not found');
    final updated = _db.prescriptions[i].copyWith(status: status);
    _db.prescriptions[i] = updated;
    return updated;
  }

  @override
  List<DrugInteraction> checkInteractions(List<String> medicationNames) {
    final lower = medicationNames.map((m) => m.toLowerCase()).toSet();
    return _knownInteractions
        .where((i) => lower.contains(i.medicationA) && lower.contains(i.medicationB))
        .toList();
  }
}
