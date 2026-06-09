/**
 * Log Error Endpoint
 * POST /functions/v1/log-error
 *
 * Public endpoint (anon key only — no user login required). Used by the
 * Flutter clients to record Dart errors that happen *before* the user is
 * authenticated (boot, splash, login screen). Authenticated errors are
 * written client-side directly via RLS; this function only covers the
 * pre-login gap where the anon role cannot insert into `app_error_logs`
 * (RLS is `TO authenticated`).
 *
 * Body: { app: 'client'|'admin', error_type, error_message,
 *         context?: object, stack_trace?: string }
 * Always returns 204 on accepted/dropped writes (never leaks), 400 on bad
 * input, 429 when rate-limited.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type, apikey',
};

// Clients may only attribute logs to these apps.
const ALLOWED_APPS = new Set(['client', 'admin']);

// Field caps (mirror the client-side LogService caps).
const MAX_MESSAGE = 2000;
const MAX_STACK = 3000;
const MAX_TYPE = 100;
const MAX_CONTEXT_BYTES = 4000;

// Best-effort in-memory rate limit (per Edge worker lifetime).
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 20;
const hits = new Map<string, number[]>();

function getClientIp(req: Request): string {
  return (
    req.headers.get('CF-Connecting-IP') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  );
}

function rateLimited(ip: string): boolean {
  const now = Date.now();
  const recent = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (recent.length >= MAX_PER_WINDOW) {
    hits.set(ip, recent);
    return true;
  }
  recent.push(now);
  hits.set(ip, recent);
  return false;
}

function clampString(v: unknown, max: number): string {
  if (typeof v !== 'string') return '';
  return v.length > max ? v.substring(0, max) : v;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405, headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }

  const ip = getClientIp(req);
  if (rateLimited(ip)) {
    return new Response(JSON.stringify({ error: 'Too many requests' }), {
      status: 429, headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }

  const app = typeof body.app === 'string' ? body.app : '';
  if (!ALLOWED_APPS.has(app)) {
    return new Response(JSON.stringify({ error: 'Invalid app' }), {
      status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }

  const errorType = clampString(body.error_type, MAX_TYPE) || 'unknown';
  const errorMessage = clampString(body.error_message, MAX_MESSAGE);
  if (!errorMessage) {
    return new Response(JSON.stringify({ error: 'Missing error_message' }), {
      status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }
  const stackTrace = body.stack_trace != null ? clampString(body.stack_trace, MAX_STACK) : null;

  let context: Record<string, unknown> = {};
  if (body.context && typeof body.context === 'object' && !Array.isArray(body.context)) {
    try {
      const serialized = JSON.stringify(body.context);
      if (serialized.length <= MAX_CONTEXT_BYTES) {
        context = body.context as Record<string, unknown>;
      } else {
        context = { _truncated: true };
      }
    } catch {
      context = {};
    }
  }
  // Stamp source so admins can distinguish from direct RLS inserts.
  context = { ...context, _via: 'log-error', _ip: ip };

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  try {
    await supabase.from('app_error_logs').insert({
      app,
      user_id: null, // pre-login by definition
      error_type: errorType,
      error_message: errorMessage,
      context,
      stack_trace: stackTrace,
    });
  } catch (e) {
    console.error('[log-error] insert failed:', e);
  }

  return new Response(null, { status: 204, headers: corsHeaders });
});
