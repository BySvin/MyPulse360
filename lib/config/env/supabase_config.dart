/// Connection details for the MyPulse360 Supabase project.
///
/// The publishable key is meant to ship inside the client — it is what the
/// app authenticates the *anonymous* role with before a user signs in. It is
/// safe to commit *because* row-level security stands between it and the
/// data, not because the key itself is secret. The service-role key is a
/// different thing entirely and lives only in the Edge Function environment.
abstract final class SupabaseConfig {
  static const String url = 'https://arxrtodtnrmhwbecwyxm.supabase.co';

  static const String publishableKey =
      'sb_publishable_RLksAvPtIo1rAepq03Pavg_p80valSC';

  const SupabaseConfig._();
}
