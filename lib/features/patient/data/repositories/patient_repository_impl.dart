import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_datasource.dart';

class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl(this._dataSource);

  final PatientDataSource _dataSource;

  @override
  PatientProfile? getProfile(String patientId) => _dataSource.getProfile(patientId);

  @override
  List<WellnessGoal> getWellnessGoals(String patientId) => _dataSource.getWellnessGoals(patientId);

  @override
  Future<PatientProfile> completeOnboarding({
    required String patientId,
    required String assignedDoctorId,
    required List<WellnessGoalType> selectedGoals,
  }) =>
      _dataSource.completeOnboarding(
        patientId: patientId,
        assignedDoctorId: assignedDoctorId,
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
  }) =>
      _dataSource.updateProfile(
        patientId,
        heightCm: heightCm,
        weightKg: weightKg,
        allergies: allergies,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodType: bloodType,
        chronicConditions: chronicConditions,
      );

  @override
  Future<void> deleteAccount(String patientId) => _dataSource.deleteAccount(patientId);
}
