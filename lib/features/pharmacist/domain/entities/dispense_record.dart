import 'package:equatable/equatable.dart';

/// Logged each time dispensing a prescription deducts stock, so Usage
/// Analytics has real data to summarize instead of only reflecting restocks.
class DispenseRecord extends Equatable {
  const DispenseRecord({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.dispensedAt,
  });

  final String id;
  final String itemId;
  final int quantity;
  final DateTime dispensedAt;

  @override
  List<Object?> get props => [id, itemId, quantity, dispensedAt];
}
