import '../entities/patient_profile.dart';
import '../entities/wellness_goal.dart';

abstract class PatientRepository {
  PatientProfile? getProfile(String patientId);

  List<WellnessGoal> getWellnessGoals(String patientId);

  /// Creates a profile + starter goals for a freshly signed-up patient.
  /// Presence of a profile is what the router treats as "onboarded".
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
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    List<String>? chronicConditions,
  });

  Future<void> deleteAccount(String patientId);
}
