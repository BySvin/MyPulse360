import '../../domain/entities/drug_interaction.dart';
import '../../domain/entities/prescription.dart';
import '../../domain/repositories/prescriptions_repository.dart';
import '../datasources/prescriptions_datasource.dart';

class PrescriptionsRepositoryImpl implements PrescriptionsRepository {
  PrescriptionsRepositoryImpl(this._dataSource);

  final PrescriptionsDataSource _dataSource;

  @override
  List<Prescription> getForPatient(String patientId) => _dataSource.getForPatient(patientId);

  @override
  List<Prescription> getPendingVerification(String pharmacyId) => _dataSource.getPendingVerification();

  @override
  Future<Prescription> create(Prescription prescription) => _dataSource.create(prescription);

  @override
  Future<Prescription> updateStatus(String prescriptionId, PrescriptionStatus status) =>
      _dataSource.updateStatus(prescriptionId, status);

  @override
  List<DrugInteraction> checkInteractions(List<String> medicationNames) =>
      _dataSource.checkInteractions(medicationNames);
}
