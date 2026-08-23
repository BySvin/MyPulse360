import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single point every datasource reaches the backend through.
///
/// Throws if read before [Supabase.initialize] has run, which is deliberate:
/// a datasource constructed too early should fail loudly at startup rather
/// than return a client that silently has no session.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
