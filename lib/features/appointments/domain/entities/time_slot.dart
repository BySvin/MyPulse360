import 'package:equatable/equatable.dart';

class TimeSlot extends Equatable {
  const TimeSlot({
    required this.dateTime,
    this.isBooked = false,
    this.isSelected = false,
    this.isDisabled = false,
    this.isDoctorOnLeave = false,
  });

  final DateTime dateTime;
  final bool isBooked;
  final bool isSelected;
  final bool isDisabled;

  /// True for every slot on a day the doctor has approved leave covering —
  /// distinct from a merely fully-booked day, so the UI can tell patients
  /// specifically why nothing is open.
  final bool isDoctorOnLeave;

  TimeSlot copyWith({bool? isSelected}) {
    return TimeSlot(
      dateTime: dateTime,
      isBooked: isBooked,
      isSelected: isSelected ?? this.isSelected,
      isDisabled: isDisabled,
      isDoctorOnLeave: isDoctorOnLeave,
    );
  }

  @override
  List<Object?> get props => [dateTime, isBooked, isSelected, isDisabled, isDoctorOnLeave];
}
