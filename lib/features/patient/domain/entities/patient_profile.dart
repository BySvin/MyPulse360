import 'package:equatable/equatable.dart';

class PatientProfile extends Equatable {
  const PatientProfile({
    required this.id,
    this.icNumber,
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
    this.preferredClinicId,
    this.preferredLanguage,
    this.notifyAppointments = true,
    this.notifyPrescriptions = true,
    this.notifyHealthTips = true,
  });

  final String id;
  final String? icNumber;

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

  /// Collected during onboarding's Healthcare Preferences step.
  final String? preferredClinicId;
  final String? preferredLanguage;
  final bool notifyAppointments;
  final bool notifyPrescriptions;
  final bool notifyHealthTips;

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
    String? icNumber,
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
  }) {
    return PatientProfile(
      id: id,
      icNumber: icNumber ?? this.icNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodType: bloodType ?? this.bloodType,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      currentMedications: currentMedications,
      assignedDoctorId: assignedDoctorId,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      preferredClinicId: preferredClinicId ?? this.preferredClinicId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notifyAppointments: notifyAppointments ?? this.notifyAppointments,
      notifyPrescriptions: notifyPrescriptions ?? this.notifyPrescriptions,
      notifyHealthTips: notifyHealthTips ?? this.notifyHealthTips,
    );
  }

  @override
  List<Object?> get props => [
        id,
        icNumber,
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
        preferredClinicId,
        preferredLanguage,
        notifyAppointments,
        notifyPrescriptions,
        notifyHealthTips,
      ];
}
