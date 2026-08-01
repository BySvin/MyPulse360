import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../domain/entities/pharmacist_profile.dart';
import '../../domain/repositories/pharmacist_repository.dart';
import '../datasources/pharmacist_datasource.dart';

class PharmacistRepositoryImpl implements PharmacistRepository {
  PharmacistRepositoryImpl(this._dataSource);

  final PharmacistDataSource _dataSource;

  @override
  PharmacistProfile? getProfile(String pharmacistId) => _dataSource.getProfile(pharmacistId);

  @override
  List<Prescription> getQueue(String pharmacyId) => _dataSource.getQueue(pharmacyId);

  @override
  List<Consultation> getAwaitingPrescription() => _dataSource.getAwaitingPrescription();
}
