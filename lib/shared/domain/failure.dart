sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Please try again.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Not authorized.']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}
