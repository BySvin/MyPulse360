import '../entities/patient_profile.dart';
import '../entities/wellness_goal.dart';

abstract class PatientRepository {
  Future<PatientProfile?> getProfile(String patientId);

  Future<List<WellnessGoal>> getWellnessGoals(String patientId);

  /// Creates a bare profile immediately after signup — before any of the
  /// onboarding steps run — so Emergency Contact / Healthcare Preferences
  /// have somewhere to save data. Presence of a profile is what the router
  /// treats as "onboarded".
  Future<PatientProfile> createInitialProfile({
    required String patientId,
    required String assignedDoctorId,
  });

  /// Seeds starter goals once the patient picks them in the Wellness Goals
  /// step. Split out from profile creation since the profile already
  /// exists by this point in the flow.
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
