import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mypulse360/features/appointments/domain/entities/appointment.dart';
import 'package:mypulse360/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:mypulse360/features/appointments/domain/usecases/book_appointment_usecase.dart';

class MockAppointmentsRepository extends Mock implements AppointmentsRepository {}

void main() {
  late MockAppointmentsRepository repository;
  late BookAppointmentUseCase useCase;

  setUp(() {
    repository = MockAppointmentsRepository();
    useCase = BookAppointmentUseCase(repository);
  });

  test('books an appointment via the repository with the given details', () async {
    final scheduledAt = DateTime(2026, 8, 1, 14);
    final booked = Appointment(
      id: 'appt-1',
      patientId: 'patient-1',
      doctorId: 'doctor-1',
      clinicId: 'clinic-001',
      scheduledAt: scheduledAt,
      durationMinutes: 30,
      appointmentType: 'General Checkup',
      status: AppointmentStatus.confirmed,
    );

    when(
      () => repository.book(
        patientId: 'patient-1',
        doctorId: 'doctor-1',
        scheduledAt: scheduledAt,
        appointmentType: 'General Checkup',
        reasonForVisit: null,
      ),
    ).thenAnswer((_) async => booked);

    final result = await useCase(
      patientId: 'patient-1',
      doctorId: 'doctor-1',
      scheduledAt: scheduledAt,
      appointmentType: 'General Checkup',
    );

    expect(result.status, AppointmentStatus.confirmed);
    expect(result.id, 'appt-1');
  });
}
