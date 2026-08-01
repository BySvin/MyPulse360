import 'package:equatable/equatable.dart';

class PharmacistProfile extends Equatable {
  const PharmacistProfile({
    required this.id,
    required this.licenseNumber,
    required this.pharmacyName,
    required this.clinicId,
  });

  final String id;
  final String licenseNumber;
  final String pharmacyName;
  final String clinicId;

  @override
  List<Object?> get props => [id, licenseNumber, pharmacyName, clinicId];
}
