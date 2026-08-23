import 'package:flutter_test/flutter_test.dart';
import 'package:mypulse360/shared/data/db_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapPostgrestError', () {
    test('turns a taken slot into words a patient understands', () {
      final failure = mapPostgrestError(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(failure.message, 'That time slot was just taken. Please pick another.');
    });

    test('turns a permission error into a refusal, not a stack trace', () {
      final failure = mapPostgrestError(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );
      expect(failure.message, "You don't have permission to do that.");
    });

    test('reports bad credentials without revealing which half was wrong', () {
      final failure = mapPostgrestError(
        const AuthException('Invalid login credentials'),
      );
      expect(failure.message, 'That email and password do not match.');
    });

    test('falls back to a generic message and keeps the cause for logging', () {
      final failure = mapPostgrestError(StateError('something odd'));
      expect(failure.message, 'Something went wrong. Please try again.');
      expect(failure.cause, isA<StateError>());
    });
  });
}
