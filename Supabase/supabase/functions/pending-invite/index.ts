/**
 * Pending Invite  [M2.4]
 *
 * POST /functions/v1/pending-invite
 * Nyilvános endpoint – a webes meghívó oldal hívja meg MIELŐTT
 * az App Store-ba irányítja a látogatót.
 * Elmenti a kliens IP-jét + metaadatait a pending_invites táblába.
 *
 * GET /functions/v1/pending-invite?check=1
 * Bearer tokennel védett – a Flutter app hívja LEGELSŐ indításakor.
 * Ha az elmúlt 1 óra IP-jei alapján egyezés van, visszaadja a tokent.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { logError } from '../_shared/logger.ts';

// ── CORS ─────────────────────────────────────────────────────
const ALLOWED_ORIGINS = [
  'http://localhost:3000',
  'http://localhost:5000',
  // 'https://yourdomain.com',
];

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin':  allowed,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}

// ── IP kinyerése ──────────────────────────────────────────────
function getRealIp(req: Request): string | null {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-real-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  );
}

// ── Main ──────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  const url    = new URL(req.url);

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders(origin) });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ── GET ?check=1 – App első indításán IP-alapú egyezés ──────
  if (req.method === 'GET' && url.searchParams.get('check') === '1') {
    const clientIp = getRealIp(req);
    if (!clientIp) {
      return new Response(JSON.stringify({ found: false, reason: 'no_ip' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    // 1 óránál nem régebbi, fel nem használt, egyező IP-jű meghívó keresése
    const { data, error } = await supabase
      .from('pending_invites')
      .select('id, token')
      .eq('client_ip', clientIp)
      .eq('is_used', false)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      await logError({ fn: 'pending-invite', error, context: { step: 'check_ip' } });
      return new Response(JSON.stringify({ found: false }), {
        status: 200,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    if (!data) {
      return new Response(JSON.stringify({ found: false }), {
        status: 200,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    // Megjelöljük felhasználtként
    await supabase
      .from('pending_invites')
      .update({ is_used: true, matched_at: new Date().toISOString() })
      .eq('id', data.id);

    return new Response(JSON.stringify({ found: true, token: data.token }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── POST – Webes meghívó oldal hívja meg a redirect előtt ───
  if (req.method === 'POST') {
    let body: { token?: string; metadata?: Record<string, string> };
    try {
      body = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    if (!body.token) {
      return new Response(JSON.stringify({ error: 'token required' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    const clientIp = getRealIp(req);
    const metadata: Record<string, string> = {
      ...(body.metadata ?? {}),
      user_agent: req.headers.get('user-agent') ?? '',
      referer:    req.headers.get('referer')    ?? '',
    };

    const { error } = await supabase
      .from('pending_invites')
      .upsert(
        {
          token:     body.token,
          client_ip: clientIp,
          metadata,
          is_used:   false,
          expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        },
        { onConflict: 'token' },
      );

    if (error) {
      await logError({ fn: 'pending-invite', error, context: { step: 'insert' } });
      return new Response(JSON.stringify({ error: 'Failed to save invite' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 201,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  return new Response(JSON.stringify({ error: 'Method not allowed' }), {
    status: 405,
    headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
  });
});
