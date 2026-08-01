import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mypulse360/features/auth/domain/entities/app_user.dart';
import 'package:mypulse360/features/auth/domain/entities/user_role.dart';
import 'package:mypulse360/features/auth/domain/repositories/auth_repository.dart';
import 'package:mypulse360/features/auth/domain/usecases/login_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late LoginUseCase useCase;

  setUp(() {
    repository = MockAuthRepository();
    useCase = LoginUseCase(repository);
  });

  const user = AppUser(
    id: 'user-1',
    email: 'sarah@example.com',
    fullName: 'Sarah Johnson',
    role: UserRole.patient,
    clinicId: 'clinic-001',
  );

  test('returns the user when the repository resolves', () async {
    when(() => repository.login(email: 'sarah@example.com', password: 'anything'))
        .thenAnswer((_) async => user);

    final result = await useCase(email: 'sarah@example.com', password: 'anything');

    expect(result, user);
    verify(() => repository.login(email: 'sarah@example.com', password: 'anything')).called(1);
  });

  test('propagates the repository failure', () async {
    when(() => repository.login(email: 'nobody@example.com', password: 'x'))
        .thenThrow(Exception('No account found'));

    expect(
      () => useCase(email: 'nobody@example.com', password: 'x'),
      throwsA(isA<Exception>()),
    );
  });
}
