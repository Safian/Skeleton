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

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin':  '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
      },
    });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
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
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
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
    return new Response(JSON.stringify({ error: 'Admin only' }), { status: 403 });
  }

  // ── Payload ────────────────────────────────────────────────────
  const { ip_address, jail } = await req.json();
  if (!ip_address) {
    return new Response(JSON.stringify({ error: 'Missing ip_address' }), { status: 400 });
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
  const { data: urlSetting } = await supabase
    .from('app_settings')
    .select('value')
    .eq('id', 'unban_webhook_url')
    .single();

  let vpsResult: Record<string, unknown> = { skipped: true };

  if (urlSetting?.value) {
    try {
      const vpsRes = await fetch(urlSetting.value, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ ip_address, jail: jail ?? 'sshd' }),
        signal:  AbortSignal.timeout(8000),
      });
      vpsResult = { ok: vpsRes.ok, status: vpsRes.status };
    } catch (err) {
      vpsResult = { error: String(err) };
      console.error('[security-unban] VPS listener error:', err);
    }
  }

  return new Response(
    JSON.stringify({ ok: true, ip_address, vps: vpsResult }),
    {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    },
  );
});
