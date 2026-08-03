import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/features/prescriptions/data/datasources/mock_prescriptions_datasource.dart';
import 'package:mypulse360/features/prescriptions/domain/entities/prescription.dart';
import 'package:mypulse360/features/prescriptions/domain/entities/prescription_item.dart';
import 'package:mypulse360/shared/mock/mock_database.dart';
import 'package:mypulse360/shared/mock/mock_ids.dart';

/// A scanned/external prescription was never verified by our pharmacist —
/// it must never appear in the pharmacist's verification queue.
void main() {
  late MockDatabase db;
  late MockPrescriptionsDataSource dataSource;

  setUp(() {
    db = MockDatabase();
    dataSource = MockPrescriptionsDataSource(db);
  });

  Prescription buildScanned() {
    final now = DateTime.now();
    return Prescription(
      id: 'rx-scanned-1',
      patientId: MockIds.sarahPatientId,
      doctorId: 'external',
      issuedDate: now,
      expiryDate: now.add(const Duration(days: 30)),
      status: PrescriptionStatus.active,
      items: const [
        PrescriptionItem(
          id: 'item-1',
          medicationName: 'Ibuprofen',
          strength: '200mg',
          form: 'tablet',
          quantity: 20,
          unit: 'tablets',
          frequency: 'As needed',
          durationDays: 10,
          instructions: '',
        ),
      ],
      source: PrescriptionSource.scannedExternal,
      externalDoctorName: 'Dr. Outside',
    );
  }

  test('a scanned prescription never appears in pending verification', () async {
    await dataSource.create(buildScanned());

    final pending = dataSource.getPendingVerification();
    expect(pending.any((p) => p.id == 'rx-scanned-1'), isFalse);
  });

  test("a scanned prescription still appears in the patient's own list", () async {
    await dataSource.create(buildScanned());

    final mine = dataSource.getForPatient(MockIds.sarahPatientId);
    expect(mine.any((p) => p.id == 'rx-scanned-1'), isTrue);
  });

  test('an in-app active prescription does appear in pending verification', () async {
    final created = await dataSource.create(
      Prescription(
        id: '',
        patientId: MockIds.sarahPatientId,
        doctorId: MockIds.drAhmedUserId,
        issuedDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        status: PrescriptionStatus.active,
        items: const [
          PrescriptionItem(
            id: 'item-2',
            medicationName: 'Metformin',
            strength: '500mg',
            form: 'tablet',
            quantity: 60,
            unit: 'tablets',
            frequency: '2x daily',
            durationDays: 30,
            instructions: 'Take with food',
          ),
        ],
        source: PrescriptionSource.inApp,
      ),
    );

    final pending = dataSource.getPendingVerification();
    expect(pending.any((p) => p.id == created.id), isTrue);
  });
}
