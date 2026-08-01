import 'package:equatable/equatable.dart';

class HealthTip extends Equatable {
  const HealthTip({
    required this.emoji,
    required this.title,
    required this.body,
    required this.category,
  });

  final String emoji;
  final String title;
  final String body;
  final String category;

  @override
  List<Object?> get props => [emoji, title, body, category];
}
