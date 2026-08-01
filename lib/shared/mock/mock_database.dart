import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/appointments/domain/entities/appointment.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/chatbot/domain/entities/chat_conversation.dart';
import '../../features/doctor/domain/entities/consultation.dart';
import '../../features/doctor/domain/entities/doctor_profile.dart';
import '../../features/health_dashboard/domain/entities/health_metric.dart';
import '../../features/patient/domain/entities/patient_profile.dart';
import '../../features/patient/domain/entities/wellness_goal.dart';
import '../../features/pharmacist/domain/entities/inventory_item.dart';
import '../../features/pharmacist/domain/entities/pharmacist_profile.dart';
import '../../features/prescriptions/domain/entities/prescription.dart';
import '../domain/entities/clinic.dart';
import 'fixtures/seed_appointments.dart';
import 'fixtures/seed_chat.dart';
import 'fixtures/seed_doctors.dart';
import 'fixtures/seed_health_metrics.dart';
import 'fixtures/seed_inventory.dart';
import 'fixtures/seed_patients.dart';
import 'fixtures/seed_pharmacists.dart';
import 'fixtures/seed_prescriptions.dart';
import 'fixtures/seed_users.dart';
import 'fixtures/seed_wellness_goals.dart';
import 'mock_ids.dart';

/// Single in-memory "backend" shared by every mock datasource this pass, so
/// e.g. booking an appointment is immediately visible in the doctor's
/// queue, and dispensing a prescription immediately flips its status for
/// the patient. Session lifetime only — resets on relaunch.
class MockDatabase {
  MockDatabase()
      : clinics = [
          const Clinic(
            id: MockIds.defaultClinicId,
            name: 'MyPulse360 Clinic',
            address: '12 Wellness Ave',
            phone: '+1 555-0100',
          ),
        ],
        users = seedUsers(),
        patients = seedPatients(),
        doctors = seedDoctors(),
        pharmacists = seedPharmacists(),
        appointments = seedAppointments(),
        prescriptions = seedPrescriptions(),
        healthMetrics = seedHealthMetrics(),
        wellnessGoals = seedWellnessGoals(),
        inventory = seedInventory(),
        chatConversations = [seedChat()],
        consultations = [];

  final List<Clinic> clinics;
  final List<AppUser> users;
  final List<PatientProfile> patients;
  final List<DoctorProfile> doctors;
  final List<PharmacistProfile> pharmacists;
  final List<Appointment> appointments;
  final List<Prescription> prescriptions;
  final List<HealthMetric> healthMetrics;
  final List<WellnessGoal> wellnessGoals;
  final List<InventoryItem> inventory;
  final List<ChatConversation> chatConversations;
  final List<Consultation> consultations;

  AppUser? userById(String id) {
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  void replaceAppointment(Appointment updated) {
    final i = appointments.indexWhere((a) => a.id == updated.id);
    if (i != -1) appointments[i] = updated;
  }

  void replacePrescription(Prescription updated) {
    final i = prescriptions.indexWhere((p) => p.id == updated.id);
    if (i != -1) prescriptions[i] = updated;
  }

  void replaceInventoryItem(InventoryItem updated) {
    final i = inventory.indexWhere((item) => item.id == updated.id);
    if (i != -1) inventory[i] = updated;
  }

  void upsertConsultation(Consultation consultation) {
    final i = consultations.indexWhere((c) => c.id == consultation.id);
    if (i == -1) {
      consultations.add(consultation);
    } else {
      consultations[i] = consultation;
    }
  }
}

final mockDatabaseProvider = Provider<MockDatabase>((ref) => MockDatabase());
