import 'package:equatable/equatable.dart';

enum ConsultationStatus { inProgress, completed }

class ConsultationVitals extends Equatable {
  const ConsultationVitals({
    this.systolicBp,
    this.diastolicBp,
    this.heartRate,
    this.temperatureCelsius,
    this.bloodSugar,
    this.weightKg,
  });

  final int? systolicBp;
  final int? diastolicBp;
  final int? heartRate;
  final double? temperatureCelsius;
  final int? bloodSugar;
  final double? weightKg;

  ConsultationVitals copyWith({
    int? systolicBp,
    int? diastolicBp,
    int? heartRate,
    double? temperatureCelsius,
    int? bloodSugar,
    double? weightKg,
  }) {
    return ConsultationVitals(
      systolicBp: systolicBp ?? this.systolicBp,
      diastolicBp: diastolicBp ?? this.diastolicBp,
      heartRate: heartRate ?? this.heartRate,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      bloodSugar: bloodSugar ?? this.bloodSugar,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  @override
  List<Object?> get props => [systolicBp, diastolicBp, heartRate, temperatureCelsius, bloodSugar, weightKg];
}

class Consultation extends Equatable {
  const Consultation({
    required this.id,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.status,
    this.vitals = const ConsultationVitals(),
    this.diagnosis,
    this.notes,
    this.recommendations,
  });

  final String id;
  final String appointmentId;
  final String patientId;
  final String doctorId;
  final ConsultationStatus status;
  final ConsultationVitals vitals;
  final String? diagnosis;
  final String? notes;
  final String? recommendations;

  @override
  List<Object?> get props =>
      [id, appointmentId, patientId, doctorId, status, vitals, diagnosis, notes, recommendations];
}
