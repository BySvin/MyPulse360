import 'package:equatable/equatable.dart';

class Supplier extends Equatable {
  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
  });

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;

  @override
  List<Object?> get props => [id, name, contactName, phone, email];
}
