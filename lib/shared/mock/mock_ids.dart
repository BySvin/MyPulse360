/// Fixed IDs shared across every fixture file so records cross-reference
/// consistently (e.g. Sarah's appointments, prescriptions, and health
/// metrics all point at the same patient id).
abstract final class MockIds {
  static const String defaultClinicId = 'clinic-001';

  static const String sarahUserId = 'user-sarah';
  static const String sarahPatientId = sarahUserId;

  static const String drAhmedUserId = 'user-dr-ahmed';
  static const String drAhmedDoctorId = drAhmedUserId;

  static const String fatimaUserId = 'user-fatima';
  static const String fatimaPharmacistId = fatimaUserId;

  // Secondary patients so the doctor/pharmacist queues aren't single-item.
  static const String patient2Id = 'user-james';
  static const String patient3Id = 'user-mei';
  static const String patient4Id = 'user-omar';

  const MockIds._();
}
