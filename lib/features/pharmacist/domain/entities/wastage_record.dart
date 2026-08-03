import 'package:equatable/equatable.dart';

enum WastageReason {
  expired,
  damaged,
  recalled,
  other;

  String get label => switch (this) {
        WastageReason.expired => 'Expired',
        WastageReason.damaged => 'Damaged',
        WastageReason.recalled => 'Recalled',
        WastageReason.other => 'Other',
      };
}

class WastageRecord extends Equatable {
  const WastageRecord({
    required this.id,
    required this.batchId,
    required this.itemId,
    required this.quantity,
    required this.reason,
    required this.recordedAt,
    required this.recordedBy,
    this.note,
  });

  final String id;
  final String batchId;
  final String itemId;
  final int quantity;
  final WastageReason reason;
  final DateTime recordedAt;
  final String recordedBy;
  final String? note;

  @override
  List<Object?> get props =>
      [id, batchId, itemId, quantity, reason, recordedAt, recordedBy, note];
}
