/// This pass runs entirely against mock/in-memory data (see the
/// implementation plan). `isMockMode` exists as the single switch to flip
/// once a real Supabase backend is wired in.
abstract final class Env {
  static const bool isMockMode = true;

  const Env._();
}
