import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../entities/pharmacist_profile.dart';

abstract class PharmacistRepository {
  PharmacistProfile? getProfile(String pharmacistId);

  /// Pending prescriptions ordered oldest-issued-first (longest wait).
  List<Prescription> getQueue(String pharmacyId);

  /// Completed consultations still waiting for the pharmacist to enter a
  /// prescription.
  List<Consultation> getAwaitingPrescription();
}
