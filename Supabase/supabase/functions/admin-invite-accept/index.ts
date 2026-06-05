/**
 * Admin Invite Accept Edge Function
 * POST /functions/v1/admin-invite-accept
 *
 * 1. Token validálás
 * 2. Supabase auth user létrehozása (signUp)
 * 3. user_profiles.role = 'admin' beállítása
 * 4. admin_invitations.is_used = true
 *
 * Body: { token: string, password: string, display_name?: string }
 * Publikus endpoint (nem kell JWT).
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

// ── CORS allow-list ────────────────────────────────────────────
// Wildcard '*' helyett explicit allow-list (lásd translate-language).
const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:5000',
  // Add your production admin URL here, e.g.:
  // 'https://admin.yourdomain.com',
];

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders(origin) });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ── Payload ────────────────────────────────────────────────────
  let body: { token: string; password: string; display_name?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  const { token, password, display_name } = body;

  if (!token || !password) {
    return new Response(
      JSON.stringify({ error: 'token és password kötelező' }),
      { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }
  if (password.length < 8) {
    return new Response(
      JSON.stringify({ error: 'A jelszónak legalább 8 karakter kell' }),
      { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  // ── 1) Token validálás RPC-vel ────────────────────────────────
  const { data: validation, error: rpcError } = await supabase.rpc(
    'validate_invitation_token',
    { p_token: token },
  );

  if (rpcError) {
    console.error('[admin-invite-accept] RPC error:', rpcError);
    return new Response(JSON.stringify({ error: 'Validációs hiba' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  if (!validation?.valid) {
    const reason = validation?.reason ?? 'invalid';
    const messages: Record<string, string> = {
      not_found:    'Ez a meghívó link nem létezik.',
      already_used: 'Ez a meghívó link már fel lett használva.',
      expired:      'Ez a meghívó link lejárt. Kérj új meghívót.',
    };
    return new Response(
      JSON.stringify({ error: messages[reason] ?? 'Érvénytelen meghívó.' }),
      { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  const { email, role } = validation as { email: string; role: string; id: string };

  // ── 2) Auth user létrehozása ───────────────────────────────────
  // Ellenőrzés: nincs-e már ilyen email
  const { data: existingUsers } = await supabase.auth.admin.listUsers();
  const alreadyExists = existingUsers?.users?.some((u) => u.email === email);

  if (alreadyExists) {
    // Ha már létezik a user, csak az admin role-t adjuk meg és a tokent invalid-áljuk
    const existingUser = existingUsers!.users.find((u) => u.email === email)!;
    await supabase.from('user_profiles')
      .update({ role })
      .eq('id', existingUser.id);

    await supabase.from('admin_invitations')
      .update({ is_used: true, accepted_at: new Date().toISOString() })
      .eq('token', token);

    return new Response(
      JSON.stringify({ ok: true, message: 'Role frissítve a meglévő fiókhoz.' }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  const { data: newUser, error: signUpError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,  // azonnal megerősítve, mert meghívón keresztül jött
    user_metadata: { display_name: display_name ?? '', invited: true },
  });

  if (signUpError || !newUser?.user) {
    console.error('[admin-invite-accept] createUser error:', signUpError);
    return new Response(
      JSON.stringify({ error: 'Regisztráció sikertelen: ' + (signUpError?.message ?? 'unknown') }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  // ── 3) Profile frissítése admin role-ra ───────────────────────
  // A handle_new_user trigger már létrehozta a profilt 'user' role-lal;
  // most felülírjuk.
  await supabase.from('user_profiles')
    .update({
      role,
      display_name: display_name ?? null,
    })
    .eq('id', newUser.user.id);

  // ── 4) Token érvénytelenítése ──────────────────────────────────
  await supabase.from('admin_invitations')
    .update({ is_used: true, accepted_at: new Date().toISOString() })
    .eq('token', token);

  return new Response(
    JSON.stringify({ ok: true, user_id: newUser.user.id, email, role }),
    {
      status: 201,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    },
  );
});
