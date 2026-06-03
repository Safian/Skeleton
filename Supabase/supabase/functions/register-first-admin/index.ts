import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ============================================================
// register-first-admin
//
// POST { email, password }
//   → Ha még nincs egyetlen user sem, létrehozza az első admint
//     email-jóváhagyás nélkül (admin API: email_confirm: true).
//   → 409 ha már létezik felhasználó (regular signup kell).
//   → 400 egyéb hiba esetén.
// ============================================================

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let email: string, password: string;
  try {
    ({ email, password } = await req.json());
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (!email || !password) {
    return json({ error: "email és password kötelező" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Ellenőrzés: létezik-e már felhasználó?
  const { data: setupCheck, error: rpcError } = await supabase
    .rpc("is_first_setup");

  if (rpcError) {
    return json({ error: rpcError.message }, 500);
  }

  if (!setupCheck) {
    return json(
      { error: "Admin már létezik. Kérj meghívót a rendszergazdától." },
      409,
    );
  }

  // Első admin létrehozása – email megerősítés nélkül
  const { error: createError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true, // bypass email verification
  });

  if (createError) {
    return json({ error: createError.message }, 400);
  }

  // Automatikus bejelentkezés
  const { data: session, error: signInError } =
    await supabase.auth.signInWithPassword({ email, password });

  if (signInError) {
    return json({ error: signInError.message }, 400);
  }

  return json({ session: session.session });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
