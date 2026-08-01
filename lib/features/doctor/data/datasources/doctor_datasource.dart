import '../../../appointments/domain/entities/appointment.dart';
import '../../domain/entities/consultation.dart';
import '../../domain/entities/doctor_profile.dart';

abstract class DoctorDataSource {
  DoctorProfile? getProfile(String doctorId);

  List<Appointment> getTodaysQueue(String doctorId);

  Consultation startOrGetConsultation(String appointmentId, String patientId, String doctorId);

  Future<Consultation> submitConsultation(Consultation consultation);

  List<Consultation> getPatientHistory(String patientId);
}
