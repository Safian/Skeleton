/**
 * GDPR Export Edge Function
 * GET /functions/v1/gdpr-export
 *
 * Authenticated user JWT required.
 * Returns a downloadable JSON file containing all personal data for the
 * requesting user (profile + items). For admin users: also exports all
 * user profiles if no user_id filter is provided.
 *
 * Query params (optional):
 *   ?user_id=<uuid>  — admin only: export a specific user's data
 */

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = [
  "http://localhost:3000",
  "http://localhost:3001",
  "http://localhost:5000",
];

function corsHeaders(origin: string | null): Record<string, string> {
  const allowed = origin &&
    (ALLOWED_ORIGINS.includes(origin) ||
      origin.startsWith("http://localhost:") ||
      origin.startsWith("http://127.0.0.1:"))
    ? origin
    : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
  };
}

function jsonError(message: string, status: number, origin: string | null): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (req.method !== "GET") {
    return jsonError("Method not allowed", 405, origin);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonError("Unauthorized", 401, origin);

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: authErr } = await userClient.auth.getUser();
  if (authErr || !user) return jsonError("Unauthorized", 401, origin);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const url = new URL(req.url);
    const targetUserId = url.searchParams.get("user_id") ?? user.id;

    // Only admins can export other users' data
    if (targetUserId !== user.id) {
      const { data: callerProfile } = await admin
        .from("user_profiles")
        .select("role")
        .eq("id", user.id)
        .single();
      if (callerProfile?.role !== "admin") {
        return jsonError("Forbidden", 403, origin);
      }
    }

    // 1. User profile
    const { data: profile, error: profileErr } = await admin
      .from("user_profiles")
      .select("id, email, role, display_name, avatar_url, created_at, language")
      .eq("id", targetUserId)
      .single();
    if (profileErr) throw profileErr;

    // 2. Items (the main app data model)
    const { data: items, error: itemsErr } = await admin
      .from("items")
      .select("id, title, content, created_at, updated_at")
      .eq("user_id", targetUserId)
      .order("created_at", { ascending: false });
    if (itemsErr) throw itemsErr;

    // 3. Legal document acceptances
    const { data: acceptances } = await admin
      .from("legal_document_acceptances")
      .select("document_id, version, accepted_at")
      .eq("user_id", targetUserId);

    // ── Build export payload ─────────────────────────────────────────────────
    const exportData = {
      export_version: "1.0",
      exported_at: new Date().toISOString(),
      scope: targetUserId === user.id ? "self" : "admin_export",
      profile,
      items: items ?? [],
      legal_acceptances: acceptances ?? [],
    };

    const dateStr = new Date().toISOString().slice(0, 10);
    const filename = `skeleton_export_${dateStr}.json`;

    return new Response(JSON.stringify(exportData, null, 2), {
      status: 200,
      headers: {
        ...corsHeaders(origin),
        "Content-Type": "application/json; charset=utf-8",
        "Content-Disposition": `attachment; filename="${filename}"`,
      },
    });
  } catch (e) {
    console.error("gdpr-export error:", e);
    return jsonError("Export failed", 500, origin);
  }
});
