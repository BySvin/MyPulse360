import '../entities/drug_interaction.dart';
import '../entities/prescription.dart';

abstract class PrescriptionsRepository {
  List<Prescription> getForPatient(String patientId);

  List<Prescription> getPendingVerification(String pharmacyId);

  Future<Prescription> create(Prescription prescription);

  Future<Prescription> updateStatus(String prescriptionId, PrescriptionStatus status);

  List<DrugInteraction> checkInteractions(List<String> medicationNames);
}
