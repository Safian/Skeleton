/**
 * Trigger Backup Edge Function
 * POST /functions/v1/trigger-backup
 *
 * Admin JWT-vel hívható. Létrehoz egy backup_logs rekordot ('running'),
 * majd opcionálisan meghívja a VPS backup webhook URL-t
 * (app_settings.backup_webhook_url + backup_webhook_secret).
 *
 * Body: { triggered_by?: string }  (default: 'manual')
 * Response: 202 Accepted + { ok, log_id, vps }
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { logError } from '../_shared/logger.ts';

const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:5000',
  // Add your production admin URL here, e.g.:
  // 'https://admin.yourdomain.com',
];

function corsHeaders(origin: string | null) {
  const allowed =
    origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
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
  let triggeredBy = 'manual';
  try {
    const body = await req.json();
    if (typeof body?.triggered_by === 'string') triggeredBy = body.triggered_by;
  } catch { /* body opcionális */ }

  // ── backup_logs rekord létrehozása ─────────────────────────────
  const { data: logRow, error: logError2 } = await supabase
    .from('backup_logs')
    .insert({
      backup_type:  'full',
      status:       'running',
      triggered_by: triggeredBy,
      metadata:     { admin_user_id: user.id },
    })
    .select('id')
    .single();

  if (logError2 || !logRow) {
    await logError({ fn: 'trigger-backup', error: logError2, context: { step: 'db_insert' } });
    return json({ error: 'DB insert sikertelen', detail: logError2?.message }, 500, origin);
  }

  // ── VPS backup webhook hívás (opcionális) ──────────────────────
  // Ha nincs webhook: DEMO MÓD – backup_logs rekord létrejön, VPS hívás elmarad.
  // Setup: app_settings → backup_webhook_url (pl. http://VPS_IP:9091/backup)
  //        app_settings → backup_webhook_secret (opcionális autentikáció)
  const { data: settingsRows } = await supabase
    .from('app_settings')
    .select('id, value')
    .in('id', ['backup_webhook_url', 'backup_webhook_secret']);

  const settings: Record<string, string> = {};
  for (const r of settingsRows ?? []) settings[r.id] = r.value;

  let vpsResult: Record<string, unknown> = {
    skipped: true,
    demo_hint: !settings.backup_webhook_url
      ? 'VPS webhook nincs beállítva – app_settings → backup_webhook_url'
      : undefined,
  };

  if (settings.backup_webhook_url) {
    let webhookUrl: URL;
    try {
      webhookUrl = new URL(settings.backup_webhook_url);
    } catch {
      vpsResult = { error: 'invalid_webhook_url' };
      return json({ ok: true, log_id: logRow.id, vps: vpsResult }, 202, origin);
    }

    if (webhookUrl.protocol !== 'http:' && webhookUrl.protocol !== 'https:') {
      vpsResult = { error: 'invalid_webhook_protocol' };
    } else {
      try {
        const headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (settings.backup_webhook_secret) {
          headers['X-Backup-Secret'] = settings.backup_webhook_secret;
        }
        const vpsRes = await fetch(webhookUrl.toString(), {
          method: 'POST',
          headers,
          body: JSON.stringify({ log_id: logRow.id, triggered_by: triggeredBy }),
          signal: AbortSignal.timeout(10_000),
        });
        vpsResult = { ok: vpsRes.ok, status: vpsRes.status };

        // Ha a VPS válaszol hibával, jelöljük meg a logot
        if (!vpsRes.ok) {
          await supabase
            .from('backup_logs')
            .update({ status: 'failed', error_message: `VPS webhook HTTP ${vpsRes.status}` })
            .eq('id', logRow.id);
        }
      } catch (err) {
        vpsResult = { error: String(err) };
        await logError({ fn: 'trigger-backup', error: err, context: { step: 'vps_webhook' } });
        await supabase
          .from('backup_logs')
          .update({ status: 'failed', error_message: String(err) })
          .eq('id', logRow.id);
      }
    }
  }

  // 202 Accepted – a tényleges backup aszinkron fut a VPS-en
  return json({ ok: true, log_id: logRow.id, vps: vpsResult }, 202, origin);
});
