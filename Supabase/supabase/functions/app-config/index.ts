/**
 * App Config Endpoint  [M5]
 * GET /functions/v1/app-config
 *
 * Nyilvános endpoint (auth nem szükséges).
 * Az app indulásakor (Splash screen alatt) hívja meg a kliens.
 * Visszaadja az app_config tábla ISMERT, whitelistelt kulcsait
 * egyetlen JSON map-ként:
 *   maintenance_mode, maintenance_message, min_app_version_*, feature_* stb.
 *   (Ismeretlen / új kulcsok szándékosan NEM kerülnek a válaszba.)
 *
 * Cache-elhető: max-age=60 fejléc van rajta,
 * hogy ne terhelje feleslegesen az adatbázist.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { logError } from '../_shared/logger.ts';

// ── Types ──────────────────────────────────────────────────────

interface AppConfigResponse {
  // Karbantartás
  maintenance_mode:    boolean;
  maintenance_message: string;
  maintenance_title:   string;

  // Verziók
  min_app_version_ios:      string;
  min_app_version_android:  string;
  latest_app_version_ios:   string;
  latest_app_version_android: string;
  app_store_url_ios:        string;
  app_store_url_android:    string;

  // Feature flagek
  feature_registration_enabled: boolean;
  feature_google_login:         boolean;
  feature_apple_login:          boolean;
  feature_push_notifications:   boolean;
  feature_bug_reporter:         boolean;
  feature_tutorial:             boolean;

  // App info
  app_name:      string;
  support_email: string;

  // Meta
  fetched_at: string;
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
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  };
}

// ── Main Handler ───────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('origin');

  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders(origin) });
  }

  if (req.method !== 'GET') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
  }

  // Service role client – az app_config publikusan olvasható,
  // de a get_app_config_map() RPC SECURITY DEFINER-rel fut.
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  // RPC hívás – egyetlen trip az adatbázishoz
  const { data, error } = await supabase.rpc('get_app_config_map');

  if (error) {
    await logError({ fn: 'app-config', error, context: { step: 'rpc_get_config' } });
    return new Response(
      JSON.stringify({ error: 'Failed to load config', detail: error.message }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
      },
    );
  }

  const configMap = (data ?? {}) as Record<string, unknown>;

  // BIZTONSÁG: csak az explicit whitelistelt kulcsokat adjuk vissza.
  // Korábban a maradék app_config sorokat is "átszórtuk" a válaszba
  // (...Object.fromEntries), ami azt jelentette volna, hogy egy jövőben
  // felvett érzékeny kulcs (pl. API titok) is kiszivároghat a publikus
  // endpointon. Ezt itt szándékosan megszüntettük – csak az ismert mezők.
  const response: AppConfigResponse = {
    maintenance_mode:           (configMap.maintenance_mode    as boolean) ?? false,
    maintenance_message:        (configMap.maintenance_message as string)  ?? '',
    maintenance_title:          (configMap.maintenance_title   as string)  ?? 'Karbantartás',

    min_app_version_ios:        (configMap.min_app_version_ios        as string) ?? '1.0.0',
    min_app_version_android:    (configMap.min_app_version_android    as string) ?? '1.0.0',
    latest_app_version_ios:     (configMap.latest_app_version_ios     as string) ?? '1.0.0',
    latest_app_version_android: (configMap.latest_app_version_android as string) ?? '1.0.0',
    app_store_url_ios:          (configMap.app_store_url_ios          as string) ?? '',
    app_store_url_android:      (configMap.app_store_url_android      as string) ?? '',

    feature_registration_enabled: (configMap.feature_registration_enabled as boolean) ?? true,
    feature_google_login:         (configMap.feature_google_login         as boolean) ?? false,
    feature_apple_login:          (configMap.feature_apple_login          as boolean) ?? false,
    feature_push_notifications:   (configMap.feature_push_notifications   as boolean) ?? false,
    feature_bug_reporter:         (configMap.feature_bug_reporter         as boolean) ?? false,
    feature_tutorial:             (configMap.feature_tutorial             as boolean) ?? true,

    app_name:      (configMap.app_name      as string) ?? 'App',
    support_email: (configMap.support_email as string) ?? '',

    fetched_at: new Date().toISOString(),
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type':  'application/json',
      // 60 másodperces cache – elég friss, nem terheli az adatbázist
      'Cache-Control': 'public, max-age=60, stale-while-revalidate=120',
      ...corsHeaders(origin),
    },
  });
});
