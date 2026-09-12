import 'package:supabase_flutter/supabase_flutter.dart';

/// A backend error with a message that can be shown to a person.
///
/// [cause] is kept for logging and never displayed — raw Postgres text leaks
/// table and column names.
class DbFailure implements Exception {
  const DbFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Translates a driver error into something a patient can act on.
///
/// The Postgres codes here are the ones the RPCs in Plan 01 raise
/// deliberately: 23505 when a slot is taken, 23514 on insufficient stock,
/// 42501 when a policy or grant refuses the caller.
DbFailure mapPostgrestError(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return DbFailure('That email and password do not match.', cause: error);
    }
    if (message.contains('already registered')) {
      return DbFailure('An account with that email already exists.', cause: error);
    }
    return DbFailure(error.message, cause: error);
  }

  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return DbFailure(
            'That time slot was just taken. Please pick another.', cause: error);
      case '23514':
        return DbFailure(
            'There is not enough stock to dispense that amount.', cause: error);
      case '42501':
      case '28000':
        return DbFailure("You don't have permission to do that.", cause: error);
      case 'P0002':
        return DbFailure('We could not find that record.', cause: error);
    }
    return DbFailure('Something went wrong: $error', cause: error);
  }

  return DbFailure('Error: $error', cause: error);
}
