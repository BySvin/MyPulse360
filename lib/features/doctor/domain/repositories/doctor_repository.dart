import '../../../appointments/domain/entities/appointment.dart';
import '../entities/consultation.dart';
import '../entities/doctor_profile.dart';

abstract class DoctorRepository {
  DoctorProfile? getProfile(String doctorId);

  List<Appointment> getTodaysQueue(String doctorId);

  Consultation startOrGetConsultation(String appointmentId, String patientId, String doctorId);

  Future<Consultation> submitConsultation(Consultation consultation);

  /// All consultations on record for a patient, most recent first — used by
  /// the doctor's patient-history view.
  List<Consultation> getPatientHistory(String patientId);
}
