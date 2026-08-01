import 'package:equatable/equatable.dart';

import 'prescription_item.dart';

enum PrescriptionStatus {
  active,
  expiring,
  expired,
  dispensed,
  cancelled;

  String get label => switch (this) {
        PrescriptionStatus.active => 'Active',
        PrescriptionStatus.expiring => 'Expiring',
        PrescriptionStatus.expired => 'Expired',
        PrescriptionStatus.dispensed => 'Dispensed',
        PrescriptionStatus.cancelled => 'Cancelled',
      };
}

class Prescription extends Equatable {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.issuedDate,
    required this.expiryDate,
    required this.status,
    required this.items,
    this.consultationId,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime issuedDate;
  final DateTime expiryDate;
  final PrescriptionStatus status;
  final List<PrescriptionItem> items;
  final String? consultationId;

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;

  Prescription copyWith({PrescriptionStatus? status}) {
    return Prescription(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      status: status ?? this.status,
      items: items,
      consultationId: consultationId,
    );
  }

  @override
  List<Object?> get props => [id, patientId, doctorId, issuedDate, expiryDate, status, items, consultationId];
}
