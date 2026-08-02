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
    when(
      () => repository.login(email: 'sarah@example.com', password: 'anything', isWebPlatform: true),
    ).thenAnswer((_) async => user);

    final result = await useCase(email: 'sarah@example.com', password: 'anything', isWebPlatform: true);

    expect(result, user);
    verify(
      () => repository.login(email: 'sarah@example.com', password: 'anything', isWebPlatform: true),
    ).called(1);
  });

  test('propagates the repository failure', () async {
    when(
      () => repository.login(email: 'nobody@example.com', password: 'x', isWebPlatform: true),
    ).thenThrow(Exception('No account found'));

    expect(
      () => useCase(email: 'nobody@example.com', password: 'x', isWebPlatform: true),
      throwsA(isA<Exception>()),
    );
  });

  test('forwards isWebPlatform through to the repository', () async {
    when(
      () => repository.login(email: 'sarah@example.com', password: 'anything', isWebPlatform: false),
    ).thenAnswer((_) async => user);

    await useCase(email: 'sarah@example.com', password: 'anything', isWebPlatform: false);

    verify(
      () => repository.login(email: 'sarah@example.com', password: 'anything', isWebPlatform: false),
    ).called(1);
  });
}
