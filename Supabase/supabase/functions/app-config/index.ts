/**
 * App Config Endpoint  [M5]
 * GET /functions/v1/app-config
 *
 * Nyilvános endpoint (auth nem szükséges).
 * Az app indulásakor (Splash screen alatt) hívja meg a kliens.
 * Visszaadja a teljes app_config táblát egyetlen JSON map-ként:
 *   maintenance_mode, maintenance_message, min_app_version_*, feature_* stb.
 *
 * Cache-elhető: max-age=60 fejléc van rajta,
 * hogy ne terhelje feleslegesen az adatbázist.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

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
  [key: string]: unknown;
}

// ── CORS fejlécek ──────────────────────────────────────────────
const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

// ── Main Handler ───────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'GET') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
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
    console.error('[app-config] RPC error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to load config', detail: error.message }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      },
    );
  }

  const configMap = (data ?? {}) as Record<string, unknown>;

  // Összerakjuk a válasz objektumot – ismeretlen kulcsok is átjönnek
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

    // Összes többi kulcs átjön (jövőbeli bővíthetőség)
    ...Object.fromEntries(
      Object.entries(configMap).filter(([k]) =>
        !['maintenance_mode','maintenance_message','maintenance_title',
          'min_app_version_ios','min_app_version_android',
          'latest_app_version_ios','latest_app_version_android',
          'app_store_url_ios','app_store_url_android',
          'feature_registration_enabled','feature_google_login',
          'feature_apple_login','feature_push_notifications',
          'feature_bug_reporter','feature_tutorial',
          'app_name','support_email',
        ].includes(k)
      )
    ),
  };

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: {
      'Content-Type':  'application/json',
      // 60 másodperces cache – elég friss, nem terheli az adatbázist
      'Cache-Control': 'public, max-age=60, stale-while-revalidate=120',
      ...corsHeaders,
    },
  });
});
