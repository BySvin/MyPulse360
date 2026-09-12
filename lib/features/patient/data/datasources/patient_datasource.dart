import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';

abstract class PatientDataSource {
  Future<PatientProfile?> getProfile(String patientId);

  Future<List<WellnessGoal>> getWellnessGoals(String patientId);

  Future<void> deleteGoal(String patientId, String goalId);

  Future<PatientProfile> createInitialProfile({
    required String patientId,
    required String assignedDoctorId,
  });

  Future<void> seedStarterGoals({
    required String patientId,
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
    String? insuranceProvider,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? preferredClinicId,
    String? preferredLanguage,
    bool? notifyAppointments,
    bool? notifyPrescriptions,
    bool? notifyHealthTips,
  });

  Future<void> deleteAccount(String patientId);
}
