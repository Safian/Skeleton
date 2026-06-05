/**
 * Session Log  [M6]
 * POST /functions/v1/session-log
 *
 * Minden sikeres bejelentkezéskor/alkalmazás-indításkor
 * a Flutter kliens elküldi az eszközadatokat.
 * Az IP-ből geo-lokációt nyerünk ki (ip-api.com – ingyenes).
 *
 * Auth: Supabase anon key (authenticated felhasználó szükséges)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

// ── Types ──────────────────────────────────────────────────────

interface SessionLogPayload {
  device_model?:   string;
  device_brand?:   string;
  os_name?:        string;
  os_version?:     string;
  app_version?:    string;
  app_build?:      string;
  locale?:         string;
  supabase_session_id?: string;
}

interface GeoResult {
  country?: string;
  city?:    string;
  lat?:     number;
  lon?:     number;
}

// ── Helpers ────────────────────────────────────────────────────

/**
 * IP-ből geo-lokáció lekérése ip-api.com segítségével.
 * Ingyenes, 45 kérés/perc limit – bőven elég auth eseményekhez.
 * Ha nem sikerül, silently fail (nem blokkol).
 */
async function getGeoFromIp(ip: string): Promise<GeoResult> {
  try {
    // Privát IP-k kihagyása
    if (
      ip.startsWith('127.') ||
      ip.startsWith('192.168.') ||
      ip.startsWith('10.') ||
      ip === '::1' ||
      ip === 'localhost'
    ) {
      return {};
    }

    const res = await fetch(
      `http://ip-api.com/json/${ip}?fields=status,country,city,lat,lon`,
      { signal: AbortSignal.timeout(3000) },
    );

    if (!res.ok) return {};

    const data = await res.json();
    if (data.status !== 'success') return {};

    return {
      country: data.country,
      city:    data.city,
      lat:     data.lat,
      lon:     data.lon,
    };
  } catch {
    return {};
  }
}

/**
 * Valós IP kinyerése a request fejlécekből.
 * Hetzner/nginx mögött a CF-Connecting-IP vagy X-Real-IP adja az igazit.
 */
function getRealIp(req: Request): string | null {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-real-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  );
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

// ── Main Handler ───────────────────────────────────────────────

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

  // ── Felhasználó azonosítása a Bearer token alapján ─────────
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // User client – a token alapján azonosítja a felhasználót
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

  // ── Payload parse ──────────────────────────────────────────
  let payload: SessionLogPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── IP + Geo ───────────────────────────────────────────────
  const ipAddress = getRealIp(req);
  const geo       = ipAddress ? await getGeoFromIp(ipAddress) : {};

  // ── Service role client az INSERT-hez (megkerüli RLS-t) ────
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // Előző aktív session-ök utolsó látott idejének frissítése
  // (ha ugyanarról az eszközről/verzióról jön ismét bejelentkezés,
  //  frissítjük a meglévő session-t a last_seen_at mezővel)
  const { data: existingSession } = await supabaseAdmin
    .from('user_sessions')
    .select('id')
    .eq('user_id', user.id)
    .eq('is_active', true)
    .eq('device_model', payload.device_model ?? '')
    .eq('app_version',  payload.app_version  ?? '')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existingSession?.id) {
    // Frissítés – nem hozunk létre duplikált session-t
    await supabaseAdmin
      .from('user_sessions')
      .update({ last_seen_at: new Date().toISOString() })
      .eq('id', existingSession.id);

    return new Response(
      JSON.stringify({ ok: true, session_id: existingSession.id, updated: true }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  // Új session létrehozása
  const { data: newSession, error: insertError } = await supabaseAdmin
    .from('user_sessions')
    .insert({
      user_id:              user.id,
      device_model:         payload.device_model   ?? null,
      device_brand:         payload.device_brand   ?? null,
      os_name:              payload.os_name         ?? null,
      os_version:           payload.os_version      ?? null,
      app_version:          payload.app_version     ?? null,
      app_build:            payload.app_build       ?? null,
      locale:               payload.locale           ?? null,
      supabase_session_id:  payload.supabase_session_id ?? null,
      ip_address:           ipAddress ?? null,
      geo_country:          geo.country ?? null,
      geo_city:             geo.city    ?? null,
      geo_lat:              geo.lat     ?? null,
      geo_lon:              geo.lon     ?? null,
      is_active:            true,
      last_seen_at:         new Date().toISOString(),
    })
    .select('id')
    .single();

  if (insertError) {
    console.error('[session-log] Insert error:', insertError);
    return new Response(
      JSON.stringify({ error: 'Failed to log session', detail: insertError.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  return new Response(
    JSON.stringify({ ok: true, session_id: newSession.id, created: true }),
    { status: 201, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
  );
});
