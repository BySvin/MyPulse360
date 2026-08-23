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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in.' }, 401);

  // Caller identity is established with the publishable key and the caller's
  // own JWT, so this respects RLS and cannot be spoofed by the request body.
  const caller = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) return json({ error: 'Not signed in.' }, 401);

  const { data: profile } = await caller
    .from('profiles').select('role, clinic_id').eq('id', user.id).maybeSingle();

  if (!profile || profile.role !== 'doctor') {
    return json({ error: 'Only doctors can create staff accounts.' }, 403);
  }

  const body = await req.json().catch(() => null);
  if (!body?.email || !body?.tempPassword || !body?.fullName || !body?.role) {
    return json({ error: 'Missing required fields.' }, 400);
  }
  if (body.role !== 'doctor' && body.role !== 'pharmacist') {
    return json({ error: 'Staff accounts must be doctor or pharmacist.' }, 400);
  }

  // A doctor provisions into their own clinic, whatever the body claims.
  const clinicId = profile.clinic_id;

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: body.email,
    password: body.tempPassword,
    email_confirm: true,
  });
  if (createError || !created.user) {
    return json({ error: createError?.message ?? 'Could not create that account.' }, 400);
  }

  const { data: inserted, error: insertError } = await admin
    .from('profiles')
    .insert({
      id: created.user.id,
      email: body.email,
      full_name: body.fullName,
      role: body.role,
      clinic_id: clinicId,
      must_change_password: true,
    })
    .select('id, email, full_name, role, clinic_id, phone, avatar_url, is_active, must_change_password')
    .single();

  if (insertError) {
    // Roll the auth user back so a failed insert does not strand an account
    // that can sign in but has no profile.
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: insertError.message }, 400);
  }

  return json(inserted, 201);
});
