import 'package:equatable/equatable.dart';

class DoctorProfile extends Equatable {
  const DoctorProfile({
    required this.id,
    required this.licenseNumber,
    required this.specialization,
    required this.clinicId,
    this.bio,
    this.averageRating,
  });

  final String id;
  final String licenseNumber;
  final String specialization;
  final String clinicId;
  final String? bio;
  final double? averageRating;

  @override
  List<Object?> get props => [id, licenseNumber, specialization, clinicId, bio, averageRating];
}
