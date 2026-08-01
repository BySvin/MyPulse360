import '../../../doctor/domain/entities/consultation.dart';
import '../../../prescriptions/domain/entities/prescription.dart';
import '../../domain/entities/pharmacist_profile.dart';

abstract class PharmacistDataSource {
  PharmacistProfile? getProfile(String pharmacistId);

  List<Prescription> getQueue(String pharmacyId);

  /// Completed consultations that don't have a prescription yet — the
  /// pharmacist's own worklist for turning a doctor's diagnosis into an
  /// actual e-prescription.
  List<Consultation> getAwaitingPrescription();
}
