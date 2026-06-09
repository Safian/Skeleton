/**
 * Send Push Notification
 * POST /functions/v1/send-push
 *
 * Admin JWT-vel hívható. FCM v1 HTTP API-n keresztül küld push értesítést
 * egy felhasználónak vagy minden felhasználónak.
 *
 * Body:
 *   { title, body, target_group: 'all'|'user', target_user_id?: string, data?: object }
 *
 * Előfeltétel: Firebase Service Account JSON az app_settings-ben, kulcs:
 *   'firebase_service_account_json' (Firebase Console → Project Settings →
 *   Service accounts → Generate new private key → a teljes JSON beillesztve).
 *
 * MEGJEGYZÉS (2026-06-06): a korábbi 'fcm_server_key' / legacy
 * `https://fcm.googleapis.com/fcm/send` endpoint Google által 2024 júniusában
 * leállításra került — ezért váltottunk FCM v1-re (Service Account + OAuth2).
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { JWT } from 'npm:google-auth-library@9.15.0';

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

type ServiceAccount = {
  project_id?: string;
  private_key?: string;
  client_email?: string;
};

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

  // ── Firebase Service Account JSON (FCM v1) ─────────────────────
  // Ha nincs beállítva: DEMO MÓD – a log DB-be kerül, FCM hívás nem történik.
  // Setup: Firebase Console → Project Settings → Service accounts →
  //        Generate new private key → a teljes JSON tartalom ide kerül
  //        (app_settings.firebase_service_account_json).
  const { data: keySetting } = await supabase
    .from('app_settings').select('value').eq('id', 'firebase_service_account_json').single();

  let serviceAccount: ServiceAccount | null = null;
  let serviceAccountError: string | null = null;
  if (keySetting?.value) {
    try {
      const parsed = JSON.parse(keySetting.value);
      if (!parsed.project_id || !parsed.private_key || !parsed.client_email) {
        serviceAccountError = 'Hiányzó mezők a Service Account JSON-ban (project_id, private_key, client_email).';
      } else {
        serviceAccount = parsed;
      }
    } catch (e) {
      serviceAccountError = `Hibás Firebase Service Account JSON formátum: ${e instanceof Error ? e.message : String(e)}`;
    }
  }
  const demoMode = !serviceAccount;

  // ── Token-ek lekérése ──────────────────────────────────────────
  let tokensQuery = supabase.from('user_push_tokens').select('id, token');
  if (target_group === 'user' && target_user_id) {
    tokensQuery = tokensQuery.eq('user_id', target_user_id) as typeof tokensQuery;
  }

  const { data: tokenRows, error: tokenError } = await tokensQuery;
  if (tokenError) return json({ error: 'Token lekérés sikertelen', detail: tokenError.message }, 500, origin);

  const tokens = (tokenRows ?? []) as { id: string; token: string }[];

  // ── FCM v1 küldés vagy demo mód ────────────────────────────────
  let successCount = 0;
  let failedCount = 0;
  let logStatus: 'sent' | 'failed' = 'sent';
  let logError: string | null = null;
  const invalidTokensToPrune: string[] = [];
  let firstErrorDetail: string | null = null;

  if (demoMode) {
    // Demo mód: nincs valódi küldés, de a log és az UI teljesen működik
    logStatus = 'sent';
    logError = serviceAccountError
      ? serviceAccountError
      : null;
    console.log(`[send-push] DEMO MODE – Firebase Service Account JSON hiányzik. Beállítás: app_settings → firebase_service_account_json (Firebase Console → Project Settings → Service accounts)`);
  } else if (tokens.length === 0) {
    // Nincs token, de logoljuk
    logStatus = 'sent';
  } else {
    // 1. OAuth2 access token a Service Accounttal (FCM v1 hatókör)
    let accessToken = '';
    try {
      const jwtClient = new JWT({
        email: serviceAccount!.client_email,
        key: serviceAccount!.private_key,
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
      });
      const tokenResponse = await jwtClient.getAccessToken();
      accessToken = tokenResponse.token ?? '';
      if (!accessToken) throw new Error('Nem sikerült lekérni az access tokent.');
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      await supabase.from('push_notification_logs').insert({
        sender_id: user.id,
        target_group,
        target_user_id: target_user_id ?? null,
        title,
        body: msgBody,
        tokens_count: tokens.length,
        status: 'failed',
        error_message: `Firebase hitelesítési hiba: ${errMsg}`,
      });
      return json({ error: `FCM Auth Error: ${errMsg}` }, 500, origin);
    }

    // 2. Küldés v1 endpointon, 50-es csomagokban (egyenkénti token üzenet —
    //    a v1 API nem támogatja a registration_ids tömeges küldést)
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount!.project_id}/messages:send`;
    const stringData: Record<string, string> = {};
    if (extraData) {
      for (const [k, v] of Object.entries(extraData)) stringData[k] = String(v);
    }

    const chunkSize = 50;
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const chunk = tokens.slice(i, i + chunkSize);

      const sends = chunk.map(async (tokenItem) => {
        const payload = {
          message: {
            token: tokenItem.token,
            notification: { title, body: msgBody },
            ...(Object.keys(stringData).length > 0 ? { data: stringData } : {}),
          },
        };

        try {
          const res = await fetch(fcmUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(payload),
          });

          if (res.status === 200) {
            successCount++;
            return;
          }

          failedCount++;
          const errorText = await res.text();
          if (!firstErrorDetail) firstErrorDetail = errorText;

          let parsedError: { error?: { status?: string } } | null = null;
          try { parsedError = JSON.parse(errorText); } catch { /* ignore parse error */ }

          const errStatus = parsedError?.error?.status;
          // Lejárt / érvénytelen token → jelöljük törlésre (dead token grooming)
          if (errStatus === 'UNREGISTERED' || errStatus === 'INVALID_ARGUMENT') {
            invalidTokensToPrune.push(tokenItem.id);
          }
          console.error(`FCM send error for token ${tokenItem.token.slice(0, 10)}…:`, errorText);
        } catch (e) {
          failedCount++;
          const errMsg = e instanceof Error ? e.message : String(e);
          if (!firstErrorDetail) firstErrorDetail = `Request failed: ${errMsg}`;
          console.error(`FCM request failed for token ${tokenItem.token.slice(0, 10)}…:`, e);
        }
      });

      await Promise.all(sends);
    }

    // 3. Halott tokenek törlése egyetlen batch művelettel
    if (invalidTokensToPrune.length > 0) {
      const { error: pruneError } = await supabase
        .from('user_push_tokens')
        .delete()
        .in('id', invalidTokensToPrune);
      if (pruneError) console.error('Prune tokens error:', pruneError);
    }

    logStatus = failedCount === tokens.length && tokens.length > 0 ? 'failed' : 'sent';
    logError = failedCount > 0
      ? `${failedCount} token sikertelen, ${successCount} sikeres, ${invalidTokensToPrune.length} elavult token törölve.${firstErrorDetail ? ` Hiba: ${firstErrorDetail}` : ''}`
      : null;
  }

  // ── Log mentése ────────────────────────────────────────────────
  await supabase.from('push_notification_logs').insert({
    sender_id: user.id,
    target_group,
    target_user_id: target_user_id ?? null,
    title,
    body: msgBody,
    tokens_count: tokens.length,
    status: logStatus,
    error_message: logError,
  });

  return json({
    ok: true,
    sent: tokens.length,
    fcm_success: successCount,
    fcm_failure: failedCount,
    pruned_tokens: invalidTokensToPrune.length,
    ...(demoMode && {
      demo_mode: true,
      setup_hint: serviceAccountError
        ?? 'FCM nincs konfigurálva. Állítsd be: app_settings → firebase_service_account_json → Firebase Console → Project Settings → Service accounts → Generate new private key.',
    }),
  }, 200, origin);
});
