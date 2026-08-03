import '../../../features/prescriptions/domain/entities/prescription.dart';
import '../../../features/prescriptions/domain/entities/prescription_item.dart';
import '../mock_ids.dart';

List<Prescription> seedPrescriptions() {
  final now = DateTime.now();

  return [
    Prescription(
      id: 'rx-sarah-metformin',
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedDoctorId,
      issuedDate: now.subtract(const Duration(days: 16)),
      expiryDate: now.add(const Duration(days: 30)),
      status: PrescriptionStatus.active,
      source: PrescriptionSource.inApp,
      items: const [
        PrescriptionItem(
          id: 'rx-item-metformin',
          medicationName: 'Metformin',
          strength: '500mg',
          form: 'tablet',
          quantity: 60,
          unit: 'tablets',
          frequency: '2x daily',
          durationDays: 30,
          instructions: 'Take with food',
          refillsAllowed: 2,
        ),
      ],
    ),
    Prescription(
      id: 'rx-sarah-atorvastatin',
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedDoctorId,
      issuedDate: now.subtract(const Duration(days: 25)),
      expiryDate: now.add(const Duration(days: 5)),
      status: PrescriptionStatus.expiring,
      source: PrescriptionSource.inApp,
      items: const [
        PrescriptionItem(
          id: 'rx-item-atorvastatin',
          medicationName: 'Atorvastatin',
          strength: '10mg',
          form: 'tablet',
          quantity: 30,
          unit: 'tablets',
          frequency: 'Nightly',
          durationDays: 30,
          instructions: 'Take at bedtime',
          refillsAllowed: 0,
        ),
      ],
    ),
    Prescription(
      id: 'rx-sarah-old',
      patientId: MockIds.sarahPatientId,
      doctorId: MockIds.drAhmedDoctorId,
      issuedDate: now.subtract(const Duration(days: 90)),
      expiryDate: now.subtract(const Duration(days: 30)),
      status: PrescriptionStatus.expired,
      source: PrescriptionSource.inApp,
      items: const [
        PrescriptionItem(
          id: 'rx-item-amoxicillin',
          medicationName: 'Amoxicillin',
          strength: '250mg',
          form: 'capsule',
          quantity: 21,
          unit: 'capsules',
          frequency: '3x daily',
          durationDays: 7,
          instructions: 'Complete full course',
        ),
      ],
    ),
    // Fresh from today's consultation, awaiting pharmacist verification.
    Prescription(
      id: 'rx-james-pending',
      patientId: MockIds.patient2Id,
      doctorId: MockIds.drAhmedDoctorId,
      issuedDate: now,
      expiryDate: now.add(const Duration(days: 30)),
      status: PrescriptionStatus.active,
      source: PrescriptionSource.inApp,
      items: const [
        PrescriptionItem(
          id: 'rx-item-lisinopril',
          medicationName: 'Lisinopril',
          strength: '10mg',
          form: 'tablet',
          quantity: 30,
          unit: 'tablets',
          frequency: 'Once daily',
          durationDays: 30,
          instructions: 'Take in the morning',
          refillsAllowed: 1,
        ),
      ],
    ),
  ];
}
