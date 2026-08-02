import 'package:equatable/equatable.dart';

class PatientProfile extends Equatable {
  const PatientProfile({
    required this.id,
    required this.heightCm,
    required this.weightKg,
    required this.allergies,
    required this.chronicConditions,
    required this.currentMedications,
    required this.assignedDoctorId,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.insuranceProvider,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String id;

  /// Optional demographic fields — genuinely absent (not a placeholder)
  /// when the patient skipped them during health profile setup.
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodType;

  final double heightCm;
  final double weightKg;
  final List<String> allergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final String assignedDoctorId;
  final String? insuranceProvider;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  String get bmiCategory {
    final value = bmi;
    if (value < 18.5) return 'Underweight';
    if (value < 25) return 'Healthy weight';
    if (value < 30) return 'Overweight';
    return 'Obese';
  }

  int? get age =>
      dateOfBirth == null ? null : (DateTime.now().difference(dateOfBirth!).inDays ~/ 365);

  PatientProfile copyWith({
    double? heightCm,
    double? weightKg,
    List<String>? allergies,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodType,
    List<String>? chronicConditions,
  }) {
    return PatientProfile(
      id: id,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      currentMedications: currentMedications,
      assignedDoctorId: assignedDoctorId,
      insuranceProvider: insuranceProvider,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
    );
  }

  @override
  List<Object?> get props => [
        id,
        dateOfBirth,
        gender,
        bloodType,
        heightCm,
        weightKg,
        allergies,
        chronicConditions,
        currentMedications,
        assignedDoctorId,
        insuranceProvider,
        emergencyContactName,
        emergencyContactPhone,
      ];
}
