import 'package:equatable/equatable.dart';

class TimeSlot extends Equatable {
  const TimeSlot({
    required this.dateTime,
    this.isBooked = false,
    this.isSelected = false,
    this.isDisabled = false,
  });

  final DateTime dateTime;
  final bool isBooked;
  final bool isSelected;
  final bool isDisabled;

  TimeSlot copyWith({bool? isSelected}) {
    return TimeSlot(
      dateTime: dateTime,
      isBooked: isBooked,
      isSelected: isSelected ?? this.isSelected,
      isDisabled: isDisabled,
    );
  }

  @override
  List<Object?> get props => [dateTime, isBooked, isSelected, isDisabled];
}
