import '../entities/time_slot.dart';
import '../repositories/appointments_repository.dart';

class GetAvailableSlotsUseCase {
  GetAvailableSlotsUseCase(this._repository);

  final AppointmentsRepository _repository;

  List<TimeSlot> call({required String doctorId, required DateTime date}) =>
      _repository.getAvailableSlots(doctorId: doctorId, date: date);
}
