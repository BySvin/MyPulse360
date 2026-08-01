enum UserRole {
  patient,
  doctor,
  pharmacist;

  String get label => switch (this) {
        UserRole.patient => 'Patient',
        UserRole.doctor => 'Doctor',
        UserRole.pharmacist => 'Pharmacist',
      };
}
