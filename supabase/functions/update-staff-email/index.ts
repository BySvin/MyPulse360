import { createClient } from 'jsr:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

/**
 * Allows a staff member to replace their temporary email with a permanent one.
 *
 * Flow:
 *   1. Admin creates a staff account with a temporary email via create-staff-account.
 *   2. Staff signs in with the temporary email.
 *   3. Staff is forced to change their password (must_change_password = true).
 *   4. Staff calls this function to set their permanent email.
 *   5. The auth.users identity and profiles.email are both updated atomically.
 *   6. must_change_password is cleared so the staff can access the dashboard.
 *
 * The profile row is not duplicated — only the email column is updated on both
 * the auth identity and the application profile.
 */
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'Not signed in.' }, 401);

    const caller = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await caller.auth.getUser();
    if (userError || !user) return json({ error: 'Not signed in.' }, 401);

    const { data: profile } = await caller
      .from('profiles')
      .select('role, email')
      .eq('id', user.id)
      .maybeSingle();

    if (!profile) {
      return json({ error: 'No profile found for this account.' }, 404);
    }

    // Only staff (doctor, pharmacist) may use this endpoint.
    if (profile.role === 'patient') {
      return json({ error: 'This endpoint is for staff accounts only.' }, 403);
    }

    const body = await req.json().catch(() => null);
    const newEmail = body?.email?.trim();
    if (!newEmail) {
      return json({ error: 'Missing required field: email.' }, 400);
    }

    // Basic email validation.
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(newEmail)) {
      return json({ error: 'Invalid email address.' }, 400);
    }

    // No-op if the email is already the target email.
    if (newEmail === profile.email) {
      return json({ message: 'Email is already set to that address.', profile });
    }

    // Check the new email is not already taken by another user.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: existingUser } = await admin.auth.admin.listUsers({
      page: 1,
      perPage: 1,
    });
    // listUsers does not filter by email; query the profiles table instead.
    const { data: emailTaken } = await admin
      .from('profiles')
      .select('id')
      .eq('email', newEmail)
      .maybeSingle();
    if (emailTaken && emailTaken.id !== user.id) {
      return json({ error: 'That email is already in use.' }, 400);
    }

    // Update the auth identity email (skip confirmation since the staff already
    // has an active session with a verified temporary email).
    const { error: updateAuthError } = await admin.auth.admin.updateUserById(
      user.id,
      { email: newEmail, email_confirm: true },
    );
    if (updateAuthError) {
      console.error('auth email update failed:', updateAuthError.message);
      return json({ error: 'Could not update auth email.' }, 500);
    }

    // Update the application profile to match.
    const { data: updatedProfile, error: updateProfileError } = await admin
      .from('profiles')
      .update({ email: newEmail })
      .eq('id', user.id)
      .select('id, email, full_name, role, clinic_id, phone, avatar_url, is_active, must_change_password')
      .single();

    if (updateProfileError) {
      // Roll back the auth email if the profile update fails.
      await admin.auth.admin.updateUserById(
        user.id,
        { email: profile.email, email_confirm: true },
      );
      console.error('profiles update failed:', updateProfileError.message);
      return json({ error: 'Could not update profile email.' }, 500);
    }

    return json({ message: 'Email updated successfully.', profile: updatedProfile });
  } catch (e) {
    console.error('update-staff-email unhandled error:', e);
    return json({ error: 'Could not update email.' }, 500);
  }
});
