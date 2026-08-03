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

/// Where a prescription record came from — whether it was issued through
/// this clinic's own doctor/pharmacist flow, or digitized by the patient
/// scanning a paper prescription from an outside prescriber. Scanned
/// prescriptions never enter the pharmacist's own verification queue,
/// since no in-app consultation or pharmacist stands behind them.
enum PrescriptionSource {
  inApp,
  scannedExternal;

  String get label => switch (this) {
        PrescriptionSource.inApp => 'Issued at this clinic',
        PrescriptionSource.scannedExternal => 'Scanned',
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
    required this.source,
    this.consultationId,
    this.externalDoctorName,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime issuedDate;
  final DateTime expiryDate;
  final PrescriptionStatus status;
  final List<PrescriptionItem> items;
  final String? consultationId;
  final PrescriptionSource source;

  /// Free-text prescriber name for a scanned/external prescription, where
  /// [doctorId] isn't a real in-app account.
  final String? externalDoctorName;

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
      source: source,
      consultationId: consultationId,
      externalDoctorName: externalDoctorName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        patientId,
        doctorId,
        issuedDate,
        expiryDate,
        status,
        items,
        consultationId,
        source,
        externalDoctorName,
      ];
}
