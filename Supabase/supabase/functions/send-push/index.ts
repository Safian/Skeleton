/**
 * Send Push Notification
 * POST /functions/v1/send-push
 *
 * Admin JWT-vel hívható. FCM-en keresztül küld push értesítést
 * egy felhasználónak vagy egy csoportnak.
 *
 * Body:
 *   { title, body, target_group: 'all'|'user', target_user_id?: string, data?: object }
 *
 * Előfeltétel: FCM_SERVER_KEY app_settings-ben (Firebase Cloud Messaging)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:3001',
  'http://localhost:5000',
];

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}

function json(body: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
  });
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders(origin) });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405, origin);
  }

  // ── Auth: admin JWT ────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
  if (authError || !user) return json({ error: 'Unauthorized' }, 401, origin);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: profile } = await supabase
    .from('user_profiles').select('role').eq('id', user.id).single();
  if (profile?.role !== 'admin') return json({ error: 'Admin only' }, 403, origin);

  // ── Payload ────────────────────────────────────────────────────
  let body: {
    title: string;
    body: string;
    target_group: 'all' | 'user';
    target_user_id?: string;
    data?: Record<string, string>;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400, origin);
  }

  const { title, body: msgBody, target_group, target_user_id, data: extraData } = body;
  if (!title || !msgBody) return json({ error: 'title és body kötelező' }, 400, origin);

  // ── FCM server key ─────────────────────────────────────────────
  const { data: keySetting } = await supabase
    .from('app_settings').select('value').eq('id', 'fcm_server_key').single();
  const fcmKey = keySetting?.value;
  if (!fcmKey) return json({ error: 'FCM server key nincs konfigurálva (app_settings.fcm_server_key)' }, 503, origin);

  // ── Token-ek lekérése ──────────────────────────────────────────
  let tokensQuery = supabase.from('user_push_tokens').select('token');
  if (target_group === 'user' && target_user_id) {
    tokensQuery = tokensQuery.eq('user_id', target_user_id) as typeof tokensQuery;
  }

  const { data: tokenRows, error: tokenError } = await tokensQuery;
  if (tokenError) return json({ error: 'Token lekérés sikertelen', detail: tokenError.message }, 500, origin);

  const tokens = (tokenRows ?? []).map((r: { token: string }) => r.token);
  if (tokens.length === 0) return json({ ok: true, sent: 0, message: 'Nincs regisztrált token' }, 200, origin);

  // ── FCM küldés (batch, max 500) ────────────────────────────────
  const notification = { title, body: msgBody };
  const fcmPayload   = { notification, data: extraData ?? {}, registration_ids: tokens };

  const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `key=${fcmKey}`,
    },
    body: JSON.stringify(fcmPayload),
  });

  const fcmResult = await fcmRes.json();

  // ── Log mentése ────────────────────────────────────────────────
  await supabase.from('push_notification_logs').insert({
    sender_id:    user.id,
    target_group,
    target_user_id: target_user_id ?? null,
    title,
    body:         msgBody,
    tokens_count: tokens.length,
    status:       fcmRes.ok ? 'sent' : 'failed',
    error_message: fcmRes.ok ? null : JSON.stringify(fcmResult),
  });

  return json({
    ok:           fcmRes.ok,
    sent:         tokens.length,
    fcm_success:  fcmResult.success ?? 0,
    fcm_failure:  fcmResult.failure ?? 0,
  }, fcmRes.ok ? 200 : 502, origin);
});
