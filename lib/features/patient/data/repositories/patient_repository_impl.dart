import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_datasource.dart';

class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl(this._dataSource);

  final PatientDataSource _dataSource;

  @override
  Future<PatientProfile?> getProfile(String patientId) =>
      _dataSource.getProfile(patientId);

  @override
  Future<List<WellnessGoal>> getWellnessGoals(String patientId) =>
      _dataSource.getWellnessGoals(patientId);

  @override
  Future<void> deleteGoal(String patientId, String goalId) =>
      _dataSource.deleteGoal(patientId, goalId);

  @override
  Future<PatientProfile> createInitialProfile({
    required String patientId,
    required String assignedDoctorId,
  }) => _dataSource.createInitialProfile(
    patientId: patientId,
    assignedDoctorId: assignedDoctorId,
  );

  @override
  Future<void> seedStarterGoals({
    required String patientId,
    required List<WellnessGoalType> selectedGoals,
  }) => _dataSource.seedStarterGoals(
    patientId: patientId,
    selectedGoals: selectedGoals,
  );

  @override
  Future<PatientProfile> updateProfile(
    String patientId, {
    double? heightCm,
    double? weightKg,
    List<String>? allergies,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    List<String>? chronicConditions,
    String? insuranceProvider,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? preferredClinicId,
    String? preferredLanguage,
    bool? notifyAppointments,
    bool? notifyPrescriptions,
    bool? notifyHealthTips,
  }) => _dataSource.updateProfile(
    patientId,
    heightCm: heightCm,
    weightKg: weightKg,
    allergies: allergies,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodType: bloodType,
    chronicConditions: chronicConditions,
    insuranceProvider: insuranceProvider,
    emergencyContactName: emergencyContactName,
    emergencyContactPhone: emergencyContactPhone,
    preferredClinicId: preferredClinicId,
    preferredLanguage: preferredLanguage,
    notifyAppointments: notifyAppointments,
    notifyPrescriptions: notifyPrescriptions,
    notifyHealthTips: notifyHealthTips,
  );

  @override
  Future<void> deleteAccount(String patientId) =>
      _dataSource.deleteAccount(patientId);
}
