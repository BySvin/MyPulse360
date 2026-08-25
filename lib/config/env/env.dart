/// Which backend the app talks to.
///
/// Defaults to the real Supabase project. Pass
/// `--dart-define=MYPULSE_MOCK=true` to run against the in-memory
/// [MockDatabase] instead — which is what the widget tests and a
/// no-network demo need.
abstract final class Env {
  static const bool isMockMode =
      bool.fromEnvironment('MYPULSE_MOCK', defaultValue: false);

  const Env._();
}
