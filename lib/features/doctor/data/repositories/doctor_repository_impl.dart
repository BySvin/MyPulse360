import '../../../appointments/domain/entities/appointment.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/entities/doctor_profile.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../datasources/doctor_datasource.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  DoctorRepositoryImpl(this._dataSource);

  final DoctorDataSource _dataSource;

  @override
  DoctorProfile? getProfile(String doctorId) => _dataSource.getProfile(doctorId);

  @override
  List<Appointment> getTodaysQueue(String doctorId) => _dataSource.getTodaysQueue(doctorId);

  @override
  Consultation startOrGetConsultation(String appointmentId, String patientId, String doctorId) =>
      _dataSource.startOrGetConsultation(appointmentId, patientId, doctorId);

  @override
  Future<Consultation> submitConsultation(Consultation consultation) =>
      _dataSource.submitConsultation(consultation);

  @override
  List<Consultation> getPatientHistory(String patientId) => _dataSource.getPatientHistory(patientId);
}
