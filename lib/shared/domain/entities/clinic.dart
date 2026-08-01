import 'package:equatable/equatable.dart';

class Clinic extends Equatable {
  const Clinic({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
  });

  final String id;
  final String name;
  final String address;
  final String phone;

  @override
  List<Object?> get props => [id, name, address, phone];
}
