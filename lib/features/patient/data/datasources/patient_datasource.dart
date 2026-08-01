import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';

abstract class PatientDataSource {
  PatientProfile? getProfile(String patientId);

  List<WellnessGoal> getWellnessGoals(String patientId);

  Future<PatientProfile> completeOnboarding({
    required String patientId,
    required String assignedDoctorId,
    required List<WellnessGoalType> selectedGoals,
  });

  Future<PatientProfile> updateProfile(
    String patientId, {
    double? heightCm,
    double? weightKg,
    List<String>? allergies,
  });

  Future<void> deleteAccount(String patientId);
}
