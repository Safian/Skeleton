/**
 * Admin Invite Edge Function
 * POST /functions/v1/admin-invite
 *
 * Meghív egy új admint e-mailben. Csak admin JWT-vel hívható.
 * Body: { email: string, role?: string, note?: string }
 *
 * E-mail küldés: Resend vagy Mailgun (app_settings alapján)
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

interface InviteBody {
  email: string;
  role?: string;
  note?: string;
}

// ── E-mail küldők ──────────────────────────────────────────────

async function sendViaResend(
  apiKey: string,
  fromEmail: string,
  fromName: string,
  toEmail: string,
  subject: string,
  html: string,
): Promise<void> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from:    `${fromName} <${fromEmail}>`,
      to:      [toEmail],
      subject,
      html,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend error ${res.status}: ${body}`);
  }
}

async function sendViaMailgun(
  apiKey: string,
  domain: string,
  fromEmail: string,
  fromName: string,
  toEmail: string,
  subject: string,
  html: string,
): Promise<void> {
  const formData = new FormData();
  formData.append('from',    `${fromName} <${fromEmail}>`);
  formData.append('to',      toEmail);
  formData.append('subject', subject);
  formData.append('html',    html);

  const res = await fetch(`https://api.mailgun.net/v3/${domain}/messages`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`api:${apiKey}`)}`,
    },
    body: formData,
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Mailgun error ${res.status}: ${body}`);
  }
}

function buildInviteHtml(
  inviteUrl: string,
  inviterEmail: string,
  role: string,
  expiresAt: string,
): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           background: #0F1117; color: #fff; margin: 0; padding: 40px 20px; }
    .card { background: #1A1D27; border-radius: 16px; padding: 40px;
            max-width: 480px; margin: 0 auto; }
    .title { font-size: 24px; font-weight: bold; margin-bottom: 12px; }
    .subtitle { color: #8FFFFFFF; font-size: 15px; line-height: 1.6; margin-bottom: 32px; }
    .btn { display: inline-block; background: #6366F1; color: #fff !important;
           padding: 14px 32px; border-radius: 12px; text-decoration: none;
           font-weight: bold; font-size: 16px; }
    .footer { margin-top: 32px; font-size: 12px; color: #61FFFFFF; }
    .badge { display: inline-block; background: #252836; padding: 4px 12px;
             border-radius: 20px; font-size: 13px; color: #6366F1; margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">🛡️ Admin meghívó</div>
    <div class="title">Meghívták az Admin Panelbe</div>
    <div class="subtitle">
      <strong>${inviterEmail}</strong> meghívott az alkalmazás admin felületére
      <strong>${role}</strong> szerepkörrel.
    </div>
    <a href="${inviteUrl}" class="btn">Regisztráció megkezdése →</a>
    <div class="footer">
      Ez a link <strong>${expiresAt}</strong>-ig érvényes.<br>
      Ha nem te kérted, hagyd figyelmen kívül ezt az e-mailt.
    </div>
  </div>
</body>
</html>`;
}

// ── Main ───────────────────────────────────────────────────────

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

  const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: profile } = await supabase
    .from('user_profiles').select('role, email').eq('id', user.id).single();

  if (profile?.role !== 'admin') {
    return new Response(JSON.stringify({ error: 'Admin only' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── Payload ────────────────────────────────────────────────────
  let body: InviteBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  const { email, role = 'admin', note } = body;

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return new Response(JSON.stringify({ error: 'Valid email required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // Ellenőrzés: nincs-e már aktív meghívó ehhez az e-mailhez
  const { data: existing } = await supabase
    .from('admin_invitations')
    .select('id')
    .eq('email', email)
    .eq('is_used', false)
    .gt('expires_at', new Date().toISOString())
    .limit(1);

  if (existing && existing.length > 0) {
    return new Response(
      JSON.stringify({ error: 'Már van aktív meghívó ehhez az e-mail címhez.' }),
      { status: 409, headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) } },
    );
  }

  // ── Meghívó létrehozása DB-ben ────────────────────────────────
  const { data: inv, error: invError } = await supabase
    .from('admin_invitations')
    .insert({ email, role, invited_by: user.id, note: note ?? null })
    .select()
    .single();

  if (invError || !inv) {
    console.error('[admin-invite] DB insert error:', invError);
    return new Response(JSON.stringify({ error: 'DB error', detail: invError?.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // ── Settings betöltése ─────────────────────────────────────────
  const { data: settingsRows } = await supabase
    .from('app_settings')
    .select('id, value')
    .in('id', [
      'app_base_url', 'smtp_from_email', 'smtp_from_name',
      'resend_api_key', 'mailgun_api_key', 'mailgun_domain',
    ]);

  const settings: Record<string, string> = {};
  for (const r of settingsRows ?? []) settings[r.id] = r.value;

  const baseUrl    = settings.app_base_url || 'https://your-app.com';
  const inviteUrl  = `${baseUrl}/invite-accept?token=${inv.token}`;
  const fromEmail  = settings.smtp_from_email || 'noreply@example.com';
  const fromName   = settings.smtp_from_name  || 'Admin';
  const expiresAt  = new Date(inv.expires_at).toLocaleString('hu-HU');

  const html = buildInviteHtml(inviteUrl, profile.email ?? user.email!, role, expiresAt);
  const subject = 'Admin meghívó – Regisztrálj most';

  // ── E-mail küldés ──────────────────────────────────────────────
  let emailSent = false;
  let emailError = '';

  try {
    if (settings.resend_api_key) {
      await sendViaResend(settings.resend_api_key, fromEmail, fromName, email, subject, html);
      emailSent = true;
    } else if (settings.mailgun_api_key && settings.mailgun_domain) {
      await sendViaMailgun(
        settings.mailgun_api_key, settings.mailgun_domain,
        fromEmail, fromName, email, subject, html,
      );
      emailSent = true;
    } else {
      emailError = 'Nincs e-mail szolgáltató konfigurálva (resend_api_key vagy mailgun_api_key).';
      console.warn('[admin-invite] No email provider configured');
    }
  } catch (err) {
    emailError = String(err);
    console.error('[admin-invite] Email send error:', err);
  }

  return new Response(
    JSON.stringify({
      ok:          true,
      invitation_id: inv.id,
      token:       inv.token,
      invite_url:  inviteUrl,
      email_sent:  emailSent,
      email_error: emailError || undefined,
    }),
    {
      status: 201,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    },
  );
});
