import '../../../features/auth/domain/entities/app_user.dart';
import '../credentials_store.dart';

/// Shared password for every seeded demo account, used by the login page's
/// "quick demo sign-in" chips. Meets the same strength rules real signups
/// are held to.
const kDemoAccountPassword = 'Passw0rd1!';

void seedDemoCredentials(CredentialsStore store, List<AppUser> users) {
  for (final user in users) {
    store.setPassword(user.id, kDemoAccountPassword);
  }
}
