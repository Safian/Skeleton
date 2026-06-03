import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(origin) });
  }

  try {
    // ── Auth: only admins may call this ─────────────────────────────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
        status: 401,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    const { data: profile } = await supabaseAdmin
      .from('user_profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();

    if (profile?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Admin role required' }), {
        status: 403,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    // ── Parse request ────────────────────────────────────────────────────────
    const body = await req.json();
    const { targetLang, missingOnly } = body as { targetLang: string; missingOnly?: boolean };

    if (!targetLang || typeof targetLang !== 'string' || targetLang.length > 10) {
      return new Response(JSON.stringify({ error: 'Invalid targetLang' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    if (targetLang === 'hu') {
      return new Response(JSON.stringify({ error: 'Cannot overwrite Hungarian source' }), {
        status: 400,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    // ── Fetch all translations ───────────────────────────────────────────────
    const { data: allRows, error: fetchErr } = await supabaseAdmin
      .from('translations')
      .select('key, hu, locales');

    if (fetchErr || !allRows) {
      return new Response(JSON.stringify({ error: 'Failed to fetch translations' }), {
        status: 500,
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    // When missingOnly=true, only process rows without a translation for targetLang.
    const rows = missingOnly
      ? allRows.filter((r) => {
          const loc = r.locales as Record<string, string> | null;
          const val = loc?.[targetLang];
          return !val || val.trim() === '';
        })
      : allRows;

    if (rows.length === 0) {
      return new Response(JSON.stringify({ count: 0 }), {
        headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
      });
    }

    // ── Build batch translation prompt ───────────────────────────────────────
    const keyValuePairs = rows.map((r) => ({ key: r.key, hu: r.hu }));
    const OPENAI_KEY = Deno.env.get('OPENAI_API_KEY') ?? '';

    const langNames: Record<string, string> = {
      en: 'English', de: 'German', fr: 'French', es: 'Spanish',
      it: 'Italian', pl: 'Polish', ro: 'Romanian', cs: 'Czech',
      sk: 'Slovak', hr: 'Croatian',
    };
    const langName = langNames[targetLang] ?? targetLang;

    // Split into batches of 80 to stay within token limits
    const BATCH = 80;
    const translated: Record<string, string> = {};

    for (let i = 0; i < keyValuePairs.length; i += BATCH) {
      const batch = keyValuePairs.slice(i, i + BATCH);
      const payload = JSON.stringify(batch);

      const gptRes = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${OPENAI_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          temperature: 0.2,
          messages: [
            {
              role: 'system',
              content:
                `You are a professional UI translator. Translate Hungarian UI strings to ${langName}. ` +
                `Rules: preserve original meaning exactly, keep placeholders like {name} or %s unchanged, ` +
                `keep emojis unchanged, keep short/concise for UI labels. ` +
                `Input: JSON array of {key, hu}. Output: a single JSON object mapping each key to its ${langName} translation. ` +
                `Output ONLY the JSON object, no explanation, no markdown.`,
            },
            {
              role: 'user',
              content: payload,
            },
          ],
          response_format: { type: 'json_object' },
        }),
      });

      if (!gptRes.ok) {
        const errText = await gptRes.text();
        console.error('OpenAI error:', errText);
        return new Response(JSON.stringify({ error: `OpenAI error: ${gptRes.status}` }), {
          status: 502,
          headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
        });
      }

      const gptData = await gptRes.json();
      const content = gptData.choices?.[0]?.message?.content ?? '{}';
      const batchResult: Record<string, string> = JSON.parse(content);
      Object.assign(translated, batchResult);
    }

    // ── Write back to DB ─────────────────────────────────────────────────────
    let count = 0;
    for (const row of rows) {
      const newTranslation = translated[row.key];
      if (!newTranslation) continue;

      const existingLocales = (row.locales as Record<string, string>) ?? {};
      const updatedLocales = { ...existingLocales, [targetLang]: newTranslation };

      const { error: updateErr } = await supabaseAdmin
        .from('translations')
        .update({ locales: updatedLocales })
        .eq('key', row.key);

      if (!updateErr) count++;
    }

    // ── Audit log ────────────────────────────────────────────────────────────
    await supabaseAdmin.from('audit_log').insert({
      action: 'ai_language_generated',
      actor_id: user.id,
      actor_email: user.email,
      actor_role: 'admin',
      target_table: 'translations',
      details: { targetLang, count, missingOnly: missingOnly ?? false },
    });

    return new Response(JSON.stringify({ count, targetLang }), {
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    });

  } catch (err) {
    console.error('translate-language error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
    });
  }
});
