import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// ─────────────────────────────────────────────────────────────────────────────
// well-known  (public — no JWT required)
//
// Serves /.well-known/apple-app-site-association and /.well-known/assetlinks.json
// Content is stored in the app_settings table under keys:
//   deeplink_aasa        → apple-app-site-association (iOS Universal Links)
//   deeplink_assetlinks  → assetlinks.json (Android App Links)
//
// Nginx routes:
//   /.well-known/apple-app-site-association → /functions/v1/well-known?file=aasa
//   /.well-known/assetlinks.json           → /functions/v1/well-known?file=assetlinks
//
// Content is cached 1h (Cache-Control: public, max-age=3600).
// ─────────────────────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
      },
    });
  }

  const url = new URL(req.url);
  const file = url.searchParams.get('file');

  if (!file || !['aasa', 'assetlinks'].includes(file)) {
    return new Response(JSON.stringify({ error: 'Unknown file requested' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const settingKey = file === 'aasa' ? 'deeplink_aasa' : 'deeplink_assetlinks';

  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/app_settings?select=value&id=eq.${settingKey}&limit=1`,
      {
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!res.ok) {
      console.error('app_settings fetch failed:', res.status, await res.text());
      return new Response('Service unavailable', { status: 503 });
    }

    const rows = await res.json() as Array<{ value: string }>;

    if (!rows || rows.length === 0 || !rows[0].value) {
      return new Response('Not configured', { status: 404 });
    }

    return new Response(rows[0].value, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (err) {
    console.error('well-known error:', err);
    return new Response('Internal error', { status: 500 });
  }
});
