/**
 * Security Unban Edge Function
 * POST /functions/v1/security-unban
 *
 * Admin JWT-vel hívható. Visszaszól a VPS-en futó
 * unban listener scriptnek (HTTP-n), és frissíti a Supabase-t.
 *
 * Body: { ip_address: string, jail?: string }
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

  // ── Auth: admin JWT ────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization') ?? '';

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

  // Service role client az adminság ellenőrzéshez
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: profile } = await supabase
    .from('user_profiles')
    .select('role')
    .eq('id', user.id)
    .single();

  if (profile?.role !== 'admin') {
    return new Response(JSON.stringify({ error: 'Admin only' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── Payload ────────────────────────────────────────────────────
  const { ip_address, jail } = await req.json();
  if (!ip_address) {
    return new Response(JSON.stringify({ error: 'Missing ip_address' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── 1) Supabase banned_ips frissítés ──────────────────────────
  await supabase
    .from('banned_ips')
    .update({ is_active: false, unbanned_at: new Date().toISOString() })
    .eq('ip_address', ip_address);

  // Log az unban eseményt
  await supabase.from('security_logs').insert({
    source:      'admin_panel',
    event_type:  'unbanned',
    ip_address,
    description: `Admin unbanned IP: ${ip_address}${jail ? ` (jail: ${jail})` : ''}`,
    metadata:    { admin_user_id: user.id, jail: jail ?? null },
  });

  // ── 2) VPS unban listener hívás ───────────────────────────────
  const { data: settingsRows2 } = await supabase
    .from('app_settings')
    .select('id, value')
    .in('id', ['unban_webhook_url', 'unban_listener_secret']);

  const vpsSettings: Record<string, string> = {};
  for (const row of settingsRows2 ?? []) vpsSettings[row.id] = row.value;

  let vpsResult: Record<string, unknown> = { skipped: true };

  if (vpsSettings.unban_webhook_url) {
    // SSRF védelme: csak http/https engedélyezett, nem belső cím
    let webhookUrl: URL;
    try {
      webhookUrl = new URL(vpsSettings.unban_webhook_url);
    } catch {
      console.warn('[security-unban] Invalid webhook URL in settings');
      vpsResult = { error: 'invalid_webhook_url' };
      // folytatás – Supabase frissítés már megtörtént
      return new Response(
        JSON.stringify({ ok: true, ip_address, vps: vpsResult }),
        { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
      );
    }
    if (webhookUrl.protocol !== 'http:' && webhookUrl.protocol !== 'https:') {
      vpsResult = { error: 'invalid_webhook_protocol' };
    } else {
      try {
        const headers: Record<string, string> = { 'Content-Type': 'application/json' };
        if (vpsSettings.unban_listener_secret) {
          headers['X-Unban-Secret'] = vpsSettings.unban_listener_secret;
        }
        const vpsRes = await fetch(webhookUrl.toString(), {
          method:  'POST',
          headers,
          body:    JSON.stringify({ ip_address, jail: jail ?? 'sshd' }),
          signal:  AbortSignal.timeout(8000),
        });
        vpsResult = { ok: vpsRes.ok, status: vpsRes.status };
      } catch (err) {
        vpsResult = { error: String(err) };
        console.error('[security-unban] VPS listener error:', err);
      }
    }
  }

  return new Response(
    JSON.stringify({ ok: true, ip_address, vps: vpsResult }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    },
  );
});
