/**
 * Bug Report  [M7]
 * POST /functions/v1/bug-report
 *
 * QA Shield – debug/staging buildből érkező hibajelentések fogadása.
 * Multipart/form-data: JSON mezők + opcionális screenshot fájl.
 *
 * Auth: opcionális (anon is küldhet – tesztelők nem mindig bejelentkezve)
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { logError } from '../_shared/logger.ts';

// ── Types ──────────────────────────────────────────────────────

interface BugReportPayload {
  title:        string;
  description?: string;
  priority?:    'low' | 'medium' | 'high' | 'critical';
  route_name?:  string;
  device_info?: Record<string, unknown>;
  logs?:        string[];
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

// ── Abuse-guard limitek ────────────────────────────────────────
// FONTOS: ez az endpoint szándékosan anonim (a tesztelők nincsenek
// mindig bejelentkezve), ezért JWT-t NEM teszünk kötelezővé.
// Service_role kulccsal fut, ezért a visszaélés ellen méret- és
// hosszkorlátokat vezetünk be, hogy ne lehessen vele a DB-t / Storage-ot
// teleszemetelni vagy nagy fájlokkal terhelni.
const MAX_SCREENSHOT_BYTES = 2 * 1024 * 1024; // 2 MB
const MAX_TITLE_LEN        = 200;
const MAX_DESCRIPTION_LEN  = 5000;
const MAX_ROUTE_LEN        = 200;
const MAX_LOGS_ENTRIES     = 200;
const MAX_LOG_ENTRY_LEN    = 2000;

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

  // Service role client az adatbázis-műveletekhez
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ── Felhasználó azonosítása (opcionális) ───────────────────
  let userId: string | null = null;
  const authHeader = req.headers.get('Authorization') ?? '';

  if (authHeader.startsWith('Bearer ')) {
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    userId = user?.id ?? null;
  }

  // ── Content-Type alapján parse ─────────────────────────────
  const contentType = req.headers.get('content-type') ?? '';
  let payload: BugReportPayload;
  let screenshotBytes: Uint8Array | null = null;
  let screenshotMime = 'image/png';

  if (contentType.includes('multipart/form-data')) {
    // Multipart: JSON + screenshot fájl
    let formData: FormData;
    try {
      formData = await req.formData();
    } catch (e) {
      return new Response(JSON.stringify({ error: 'Invalid multipart form' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    const jsonStr = formData.get('data');
    if (!jsonStr || typeof jsonStr !== 'string') {
      return new Response(JSON.stringify({ error: 'Missing "data" field in form' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    try {
      payload = JSON.parse(jsonStr);
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid JSON in "data" field' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }

    const screenshotFile = formData.get('screenshot');
    if (screenshotFile instanceof File) {
      // Abuse-guard: a 2 MB-nál nagyobb screenshotot visszautasítjuk.
      if (screenshotFile.size > MAX_SCREENSHOT_BYTES) {
        return new Response(
          JSON.stringify({ error: 'Screenshot too large (max 2MB)' }),
          { status: 413, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
        );
      }
      screenshotBytes = new Uint8Array(await screenshotFile.arrayBuffer());
      screenshotMime  = screenshotFile.type || 'image/png';
    }
  } else {
    // Sima JSON (screenshot nélkül)
    try {
      payload = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      });
    }
  }

  // ── Validáció ──────────────────────────────────────────────
  if (!payload.title?.trim()) {
    return new Response(JSON.stringify({ error: 'Missing required field: title' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // Abuse-guard: hosszkorlátok a szöveges mezőkön, hogy ne lehessen
  // a service_role-os endpointtal a DB-t óriási payloadokkal terhelni.
  if (
    payload.title.length > MAX_TITLE_LEN ||
    (payload.description?.length ?? 0) > MAX_DESCRIPTION_LEN ||
    (payload.route_name?.length ?? 0) > MAX_ROUTE_LEN ||
    (Array.isArray(payload.logs) && (
      payload.logs.length > MAX_LOGS_ENTRIES ||
      payload.logs.some((l) => typeof l === 'string' && l.length > MAX_LOG_ENTRY_LEN)
    ))
  ) {
    return new Response(JSON.stringify({ error: 'Payload field too large' }), {
      status: 413,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  const priority = (['low','medium','high','critical'] as const)
    .includes(payload.priority as never)
    ? payload.priority!
    : 'medium';

  // ── Bug report mentése ─────────────────────────────────────
  const { data: bugRow, error: insertError } = await supabase
    .from('bug_reports')
    .insert({
      reporter_id: userId,
      title:       payload.title.trim(),
      description: payload.description?.trim() ?? null,
      priority,
      route_name:  payload.route_name  ?? null,
      device_info: payload.device_info ?? {},
      logs:        payload.logs        ?? [],
      status:      'open',
    })
    .select('id')
    .single();

  if (insertError) {
    await logError({ fn: 'bug-report', error: insertError, context: { step: 'db_insert' } });
    return new Response(
      JSON.stringify({ error: 'Failed to save bug report', detail: insertError.message }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  const bugId = bugRow.id as string;

  // ── Screenshot feltöltése Supabase Storage-ba ─────────────
  let screenshotUrl: string | null = null;

  if (screenshotBytes && screenshotBytes.length > 0) {
    const ext        = screenshotMime.includes('jpeg') ? 'jpg' : 'png';
    const storagePath = `${bugId}/${Date.now()}.${ext}`;

    const { error: uploadError } = await supabase.storage
      .from('bug-screenshots')
      .upload(storagePath, screenshotBytes, {
        contentType: screenshotMime,
        upsert:      false,
      });

    if (uploadError) {
      console.warn('[bug-report] Screenshot upload failed:', uploadError.message);
      // Nem blokkoló – a bug report mentése sikerült screenshot nélkül
    } else {
      const { data: { publicUrl } } = supabase.storage
        .from('bug-screenshots')
        .getPublicUrl(storagePath);

      screenshotUrl = publicUrl;

      // Frissítjük a bug report-ot a screenshot URL-lel
      await supabase
        .from('bug_reports')
        .update({ screenshot_url: screenshotUrl })
        .eq('id', bugId);
    }
  }

  // ── Telegram értesítés (ha be van állítva) ─────────────────
  try {
    const { data: settingsRows } = await supabase
      .from('app_settings')
      .select('id, value')
      .in('id', ['telegram_bot_token', 'telegram_chat_id']);

    const settings: Record<string, string> = {};
    for (const row of settingsRows ?? []) settings[row.id] = row.value;

    if (settings.telegram_bot_token && settings.telegram_chat_id) {
      const priorityEmoji: Record<string, string> = {
        critical: '🔴', high: '🟠', medium: '🟡', low: '🟢',
      };
      const msg = [
        `${priorityEmoji[priority] ?? '🐛'} *BUG REPORT* [${priority.toUpperCase()}]`,
        ``,
        `*Cím:* ${payload.title}`,
        payload.description ? `*Leírás:* ${payload.description}` : null,
        `*Route:* \`${payload.route_name ?? 'N/A'}\``,
        payload.device_info?.app_version
          ? `*Verzió:* ${payload.device_info.app_version}` : null,
        payload.device_info?.os_name
          ? `*OS:* ${payload.device_info.os_name} ${payload.device_info.os_version ?? ''}`.trim() : null,
        screenshotUrl ? `[Screenshot](${screenshotUrl})` : null,
      ].filter(Boolean).join('\n');

      await fetch(
        `https://api.telegram.org/bot${settings.telegram_bot_token}/sendMessage`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id:    settings.telegram_chat_id,
            text:       msg,
            parse_mode: 'Markdown',
          }),
        },
      );
    }
  } catch (e) {
    console.warn('[bug-report] Telegram notify failed:', e);
  }

  return new Response(
    JSON.stringify({ ok: true, bug_id: bugId, screenshot_url: screenshotUrl }),
    {
      status:  201,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    },
  );
});
