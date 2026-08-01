import 'package:equatable/equatable.dart';

class PatientProfile extends Equatable {
  const PatientProfile({
    required this.id,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodType,
    required this.heightCm,
    required this.weightKg,
    required this.allergies,
    required this.chronicConditions,
    required this.currentMedications,
    required this.assignedDoctorId,
    this.insuranceProvider,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String id;
  final DateTime dateOfBirth;
  final String gender;
  final String bloodType;
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

  PatientProfile copyWith({double? heightCm, double? weightKg, List<String>? allergies}) {
    return PatientProfile(
      id: id,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodType: bloodType,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions,
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
