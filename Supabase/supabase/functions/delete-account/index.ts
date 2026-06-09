/**
 * Delete Account  [GDPR]
 * POST /functions/v1/delete-account
 *
 * Az authentikált felhasználó saját fiókját törli véglegesen.
 * auth.users-ből való törlés cascade-del magával viszi:
 *   - user_profiles (CASCADE)
 *   - items (CASCADE)
 *   - user_sessions (CASCADE)
 *
 * Auth: kötelező Bearer JWT (csak a saját fiókod törölheted)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { logError } from '../_shared/logger.ts';

const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:5000',
  // Add your production URL here, e.g.:
  // 'https://app.yourdomain.com',
];

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
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

  // ── Auth: kötelező Bearer JWT ──────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── Törlés service_role-lal (bypass RLS) ───────────────────────
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id);

  if (deleteError) {
    await logError({ fn: 'delete-account', error: deleteError, context: { step: 'delete_user', userId: user.id } });
    return new Response(
      JSON.stringify({ error: 'Account deletion failed', detail: deleteError.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true }),
    { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
  );
});
