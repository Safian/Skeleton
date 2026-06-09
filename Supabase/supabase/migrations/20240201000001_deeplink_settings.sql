-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: Deep Link app_settings
--
-- Adds three app_settings rows needed for Universal Links / App Links
-- and in-app deep link routing.
--
--   deeplink_url_mappings  → Flutter DeepLinkHandler action routing table
--   deeplink_aasa          → iOS Universal Links  (/.well-known/apple-app-site-association)
--   deeplink_assetlinks    → Android App Links    (/.well-known/assetlinks.json)
--
-- Required env on VPS: DEEPLINK_JWT_SECRET (min 32 chars)
--   Generate: openssl rand -hex 32
--   Add to /opt/supabase/docker/.env, then restart supabase-edge-functions.
--
-- Also add to Nginx:
--   location = /.well-known/apple-app-site-association {
--     proxy_pass http://kong:8000/functions/v1/well-known?file=aasa;
--   }
--   location = /.well-known/assetlinks.json {
--     proxy_pass http://kong:8000/functions/v1/well-known?file=assetlinks;
--   }
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. In-app URL → action mapping ───────────────────────────────────────────
-- Consumed by DeepLinkHandler._loadMappings() in the Flutter app.
-- Wildcard segments use :paramName notation (matched left-to-right, exact depth).
-- /link/:token  → resolve_token calls the resolve-deeplink edge function.
INSERT INTO public.app_settings (id, value, description)
VALUES (
  'deeplink_url_mappings',
  '[
    {"path": "/invite-accept", "action": "invite"},
    {"path": "/link/:token",   "action": "resolve_token"}
  ]',
  'URL path → action mappings for the Flutter DeepLinkHandler. Format: [{path, action}]. Parameterised segments: :name. resolve_token invokes the resolve-deeplink edge function.'
)
ON CONFLICT (id) DO UPDATE SET value = EXCLUDED.value;

-- ── 2. iOS Universal Links — AASA ────────────────────────────────────────────
-- Served by the well-known edge function at /.well-known/apple-app-site-association.
-- Uses modern "components" format (iOS 14+).
-- appID = <TeamID>.<BundleID>  — update with your Apple Team ID and bundle ID.
INSERT INTO public.app_settings (id, value, description)
VALUES (
  'deeplink_aasa',
  '{
    "applinks": {
      "details": [
        {
          "appIDs": ["8R7QAX93QJ.hu.safian.skeleton.flutter.dev"],
          "components": [
            { "/": "/invite-accept*", "comment": "Invite acceptance" },
            { "/": "/link/*",         "comment": "Token-based deep link (JWT)" }
          ]
        }
      ]
    }
  }',
  'Apple App Site Association JSON for iOS Universal Links. Served at /.well-known/apple-app-site-association via the well-known edge function. appID = TeamID.BundleID.'
)
ON CONFLICT (id) DO UPDATE SET value = EXCLUDED.value;

-- ── 3. Android App Links — assetlinks.json ───────────────────────────────────
-- Served by the well-known edge function at /.well-known/assetlinks.json.
-- SHA256 fingerprint: extract from your upload keystore:
--   keytool -list -v -keystore android/app/upload-keystore.jks -alias upload
-- If Play App Signing is enabled, use the fingerprint from:
--   Play Console → Setup → App signing → App signing key certificate.
INSERT INTO public.app_settings (id, value, description)
VALUES (
  'deeplink_assetlinks',
  '[
    {
      "relation": ["delegate_permission/common.handle_all_urls"],
      "target": {
        "namespace": "android_app",
        "package_name": "hu.safian.skeleton.flutter.dev",
        "sha256_cert_fingerprints": [
          "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
        ]
      }
    }
  ]',
  'Android Digital Asset Links JSON for App Links. Served at /.well-known/assetlinks.json via the well-known edge function. Replace sha256_cert_fingerprints with your actual keystore fingerprint.'
)
ON CONFLICT (id) DO UPDATE SET value = EXCLUDED.value;

SELECT 'Migration: deeplink app_settings inserted/updated' AS result;
