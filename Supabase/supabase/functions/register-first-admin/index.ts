/**
 * Register First Admin
 * POST /functions/v1/register-first-admin
 *
 * Csak akkor hozza létre az első admint, ha még egyetlen felhasználó
 * sincs a rendszerben (is_first_setup RPC ellenőrzi).
 *
 * Biztonság:
 *  - SETUP_TOKEN env var: ha be van állítva, a kérésnek tartalmaznia kell
 *  - Teljes session NEM kerül vissza (csak ok: true) – a kliensnek külön
 *    be kell jelentkeznie, hogy ne kerüljön naplókba a refresh_token
 *  - 409 ha már van felhasználó
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  let email: string, password: string, setupToken: string | undefined;
  try {
    ({ email, password, setup_token: setupToken } = await req.json());
  } catch {
    return json({ error: 'Invalid JSON body' }, 400);
  }

  if (!email || !password) {
    return json({ error: 'email és password kötelező' }, 400);
  }

  if (password.length < 8) {
    return json({ error: 'A jelszónak legalább 8 karakter kell' }, 400);
  }

  // ── Setup token ellenőrzés ─────────────────────────────────────
  // Ha a SETUP_TOKEN env var be van állítva, a kérésnek meg kell egyeznie.
  // Ha nincs beállítva, csak local/dev módban működik (is_first_setup gate marad).
  const requiredToken = Deno.env.get('SETUP_TOKEN');
  if (requiredToken) {
    if (!setupToken || setupToken !== requiredToken) {
      return json({ error: 'Unauthorized: invalid setup_token' }, 401);
    }
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // ── Atomi check: van-e már felhasználó? ────────────────────────
  // Az is_first_setup RPC advisory lock-kal garantálja az atomicitást,
  // hogy párhuzamos kérések ne tudjanak egyszerre átmenni.
  const { data: setupCheck, error: rpcError } = await supabase
    .rpc('is_first_setup');

  if (rpcError) {
    return json({ error: rpcError.message }, 500);
  }

  if (!setupCheck) {
    return json(
      { error: 'Admin már létezik. Kérj meghívót a rendszergazdától.' },
      409,
    );
  }

  // ── Első admin létrehozása ─────────────────────────────────────
  const { data: created, error: createError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (createError || !created?.user) {
    return json({ error: createError?.message ?? 'User creation failed' }, 400);
  }

  // ── Teljes session NEM kerül vissza (naplózási kockázat elkerülése)
  // A kliensnek külön kell bejelentkeznie signInWithEmailPassword-del.
  return json({ ok: true, user_id: created.user.id });
});
