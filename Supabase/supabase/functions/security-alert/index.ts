/**
 * Security Alert Webhook
 * POST /functions/v1/security-alert
 *
 * Fogad egy biztonsági eseményt, menti Supabase-be,
 * és értesítést küld Telegram-on vagy Discord-on.
 *
 * Auth: Bearer token (app_settings.security_webhook_api_key)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { logError } from '../_shared/logger.ts';

// ── Types ──────────────────────────────────────────────────────

interface SecurityAlertPayload {
  timestamp?: string;
  source: string;       // 'fail2ban' | 'ssh_monitor' | 'auth_service'
  event_type: string;   // 'brute_force' | 'successful_ssh_login' | 'rate_limit_exceeded'
  ip_address?: string;
  description?: string;
  metadata?: Record<string, unknown>;
}

interface AppSettings {
  telegram_bot_token: string;
  telegram_chat_id: string;
  discord_webhook_url: string;
}

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
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}

// Konstans idejű string-összehasonlítás (timing side-channel ellen).
// A sima !== a karakterenkénti rövidzárlat miatt elárulhatja, hány
// karakter egyezett – ezt elkerüljük: előbb hossz, majd XOR-akkumulátor.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

// ── Helpers ────────────────────────────────────────────────────

function eventEmoji(event_type: string): string {
  switch (event_type) {
    case 'brute_force':           return '🚨';
    case 'successful_ssh_login':  return '🔑';
    case 'rate_limit_exceeded':   return '⚠️';
    case 'port_scan':             return '🔍';
    case 'banned':                return '🚫';
    case 'unbanned':              return '✅';
    default:                      return '🔔';
  }
}

function buildNotificationText(payload: SecurityAlertPayload): string {
  const emoji  = eventEmoji(payload.event_type);
  const ts     = payload.timestamp
    ? new Date(payload.timestamp).toISOString()
    : new Date().toISOString();

  return [
    `${emoji} *SECURITY ALERT*`,
    ``,
    `*Type:*  \`${payload.event_type}\``,
    `*Source:* \`${payload.source}\``,
    `*IP:*    \`${payload.ip_address ?? 'N/A'}\``,
    `*Time:*  \`${ts}\``,
    payload.description ? `*Info:*  ${payload.description}` : null,
  ]
    .filter(Boolean)
    .join('\n');
}

async function sendTelegram(token: string, chatId: string, text: string): Promise<void> {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      chat_id:    chatId,
      text,
      parse_mode: 'Markdown',
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    await logError({ fn: 'security-alert', error: new Error(body), context: { step: 'telegram_notify', status: res.status } });
  }
}

async function sendDiscord(webhookUrl: string, text: string): Promise<void> {
  const res = await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: text }),
  });
  if (!res.ok) {
    const body = await res.text();
    await logError({ fn: 'security-alert', error: new Error(body), context: { step: 'discord_notify', status: res.status } });
  }
}

// ── Main Handler ───────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');

  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders(origin) });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── Service-role client (megkerüli az RLS-t) ──────────────────
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ── Auth: Bearer token ellenőrzés ─────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';
  const token      = authHeader.replace(/^Bearer\s+/i, '').trim();

  if (!token) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // API kulcs ellenőrzés az app_settings táblából
  const { data: keySetting, error: keyError } = await supabase
    .from('app_settings')
    .select('value')
    .eq('id', 'security_webhook_api_key')
    .single();

  // Konstans idejű összehasonlítás – nem a sima !== (timing side-channel ellen).
  if (keyError || !keySetting?.value || !timingSafeEqual(String(keySetting.value), token)) {
    console.warn('[security-alert] Invalid API key attempt');
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── Payload parse ──────────────────────────────────────────────
  let payload: SecurityAlertPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // Kötelező mezők
  if (!payload.source || !payload.event_type) {
    return new Response(
      JSON.stringify({ error: 'Missing required fields: source, event_type' }),
      { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  // ── 1) Mentés security_logs táblába ───────────────────────────
  const { data: logRow, error: insertError } = await supabase
    .from('security_logs')
    .insert({
      timestamp:   payload.timestamp ?? new Date().toISOString(),
      source:      payload.source,
      event_type:  payload.event_type,
      ip_address:  payload.ip_address ?? null,
      description: payload.description ?? null,
      metadata:    payload.metadata ?? {},
    })
    .select()
    .single();

  if (insertError) {
    await logError({ fn: 'security-alert', error: insertError, context: { step: 'db_insert' } });
    return new Response(JSON.stringify({ error: 'Failed to save log', detail: insertError.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── 2) Ha brute_force/banned → rögzítjük banned_ips-be ────────
  if (
    payload.ip_address &&
    ['brute_force', 'banned'].includes(payload.event_type)
  ) {
    await supabase.from('banned_ips').upsert(
      {
        ip_address: payload.ip_address,
        reason:     payload.description ?? payload.event_type,
        jail:       (payload.metadata?.jail as string) ?? null,
        log_id:     logRow.id,
        is_active:  true,
      },
      { onConflict: 'ip_address', ignoreDuplicates: false },
    );
  }

  // Ha unbanned → frissítjük banned_ips-t
  if (payload.ip_address && payload.event_type === 'unbanned') {
    await supabase
      .from('banned_ips')
      .update({ is_active: false, unbanned_at: new Date().toISOString() })
      .eq('ip_address', payload.ip_address);
  }

  // ── 3) Értesítések küldése ─────────────────────────────────────
  const { data: settingsRows } = await supabase
    .from('app_settings')
    .select('id, value')
    .in('id', ['telegram_bot_token', 'telegram_chat_id', 'discord_webhook_url']);

  const settings: Record<string, string> = {};
  for (const row of settingsRows ?? []) {
    settings[row.id] = row.value;
  }

  const notifText = buildNotificationText(payload);

  const notifPromises: Promise<void>[] = [];

  // Telegram
  if (settings.telegram_bot_token && settings.telegram_chat_id) {
    notifPromises.push(
      sendTelegram(settings.telegram_bot_token, settings.telegram_chat_id, notifText),
    );
  }

  // Discord
  if (settings.discord_webhook_url) {
    notifPromises.push(sendDiscord(settings.discord_webhook_url, notifText));
  }

  await Promise.allSettled(notifPromises);

  // ── Response ───────────────────────────────────────────────────
  return new Response(
    JSON.stringify({ ok: true, log_id: logRow.id }),
    {
      status: 201,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    },
  );
});
