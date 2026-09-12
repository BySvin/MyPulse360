import '../../../../shared/mock/mock_database.dart';
import '../../../../shared/utils/id_generator.dart';
import '../../../../shared/utils/mock_latency.dart';
import '../../domain/entities/patient_profile.dart';
import '../../domain/entities/wellness_goal.dart';
import 'patient_datasource.dart';

class MockPatientDataSource implements PatientDataSource {
  MockPatientDataSource(this._db);

  final MockDatabase _db;

  @override
  Future<PatientProfile?> getProfile(String patientId) async {
    for (final p in _db.patients) {
      if (p.id == patientId) return p;
    }
    return null;
  }

  @override
  Future<List<WellnessGoal>> getWellnessGoals(String patientId) async =>
      _db.wellnessGoals.where((g) => g.patientId == patientId).toList();

  @override
  Future<void> deleteGoal(String patientId, String goalId) async {
    await simulateLatency();
    _db.wellnessGoals.removeWhere(
      (g) => g.id == goalId && g.patientId == patientId,
    );
  }

  @override
  Future<PatientProfile> createInitialProfile({
    required String patientId,
    required String assignedDoctorId,
  }) async {
    await simulateLatency();
    // Height/weight need a real (non-null) starting value since the entity
    // requires them; Health Profile Setup (the last onboarding step)
    // immediately overwrites these. Everything else stays genuinely empty
    // until the patient fills it in across the onboarding steps.
    final profile = PatientProfile(
      id: patientId,
      heightCm: 170,
      weightKg: 70,
      allergies: const [],
      chronicConditions: const [],
      currentMedications: const [],
      assignedDoctorId: assignedDoctorId,
    );
    _db.patients.add(profile);
    return profile;
  }

  @override
  Future<void> seedStarterGoals({
    required String patientId,
    required List<WellnessGoalType> selectedGoals,
  }) async {
    await simulateLatency();
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday));
    for (final type in selectedGoals) {
      final (target, unit) = switch (type) {
        WellnessGoalType.exercise => (5.0, 'sessions'),
        WellnessGoalType.hydration => (8.0, 'glasses'),
        WellnessGoalType.sleep => (8.0, 'hours avg'),
        WellnessGoalType.diet => (3.0, 'meals logged'),
        WellnessGoalType.custom => (1.0, 'times'),
      };
      _db.wellnessGoals.add(
        WellnessGoal(
          id: generateId(),
          patientId: patientId,
          type: type,
          name: type.label,
          targetValue: target,
          currentValue: 0,
          unit: unit,
          status: GoalStatus.onTrack,
          targetDate: endOfWeek,
        ),
      );
    }
  }

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
  }) async {
    await simulateLatency();
    final i = _db.patients.indexWhere((p) => p.id == patientId);
    if (i == -1) throw StateError('Patient profile not found');
    final updated = _db.patients[i].copyWith(
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
    _db.patients[i] = updated;
    return updated;
  }

  @override
  Future<void> deleteAccount(String patientId) async {
    await simulateLatency();
    _db.patients.removeWhere((p) => p.id == patientId);
    _db.users.removeWhere((u) => u.id == patientId);
  }
}
