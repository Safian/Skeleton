-- ============================================================
-- Migration 007: App Config, Feature Flags, App Versions
-- Remote konfigurációs tábla – Splash screen alatt töltődik be.
-- ============================================================

-- ── app_config ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_config (
  key         TEXT PRIMARY KEY,
  value       TEXT NOT NULL DEFAULT '',
  value_type  TEXT NOT NULL DEFAULT 'string',  -- 'string' | 'bool' | 'int' | 'json'
  description TEXT NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Publikus olvasás (anon is elérheti – app indulásakor)
CREATE POLICY "Public read app_config"
  ON public.app_config FOR SELECT TO public USING (true);

-- Csak admin írhat
CREATE POLICY "Admins manage app_config"
  ON public.app_config FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access app_config"
  ON public.app_config FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- updated_at trigger
CREATE TRIGGER on_app_config_updated
  BEFORE UPDATE ON public.app_config
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── Alapértelmezett konfig értékek ────────────────────────────
INSERT INTO public.app_config (key, value, value_type, description) VALUES
  -- Maintenance
  ('maintenance_mode',     'false', 'bool',   'Ha true, az app maintenance képernyőt mutat.'),
  ('maintenance_message',  'Az alkalmazás karbantartás alatt áll. Hamarosan visszatérünk!', 'string', 'Karbantartás üzenet (HTML is elfogadott).'),
  ('maintenance_title',    'Karbantartás', 'string', 'Karbantartás képernyő főcíme.'),

  -- App versions
  ('min_app_version_ios',      '1.0.0', 'string', 'Minimálisan szükséges iOS app verzió (force update).'),
  ('min_app_version_android',  '1.0.0', 'string', 'Minimálisan szükséges Android app verzió (force update).'),
  ('latest_app_version_ios',   '1.0.0', 'string', 'Legfrissebb iOS verzió (soft update figyelmeztetés).'),
  ('latest_app_version_android','1.0.0','string', 'Legfrissebb Android verzió (soft update figyelmeztetés).'),
  ('app_store_url_ios',        '',      'string', 'iOS App Store link a force/soft update-hoz.'),
  ('app_store_url_android',    '',      'string', 'Google Play link a force/soft update-hoz.'),

  -- Feature flags
  ('feature_registration_enabled',  'true',  'bool', 'Engedélyezi-e az új regisztrációt.'),
  ('feature_google_login',          'false', 'bool', 'Google OAuth bejelentkezés aktív-e.'),
  ('feature_apple_login',           'false', 'bool', 'Apple Sign In aktív-e.'),
  ('feature_push_notifications',    'false', 'bool', 'Push értesítések küldése aktív-e.'),
  ('feature_dark_mode_only',        'true',  'bool', 'Csak sötét téma engedélyezett.'),
  ('feature_bug_reporter',          'false', 'bool', 'In-app bug reporter aktív-e (debug/staging).'),
  ('feature_tutorial',              'true',  'bool', 'Feature Walkthrough tutorial aktív-e.'),

  -- App info
  ('app_name',    'Skeleton App', 'string', 'Az alkalmazás neve.'),
  ('support_email','support@example.com','string','Támogatási e-mail cím.'),
  ('privacy_url', '','string','Adatvédelmi nyilatkozat URL.'),
  ('terms_url',   '','string','ÁSZF URL.')
ON CONFLICT (key) DO NOTHING;

-- ── RPC: get_app_config_map ────────────────────────────────────
-- Minden konfigot egyetlen map-ban ad vissza
CREATE OR REPLACE FUNCTION public.get_app_config_map()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb := '{}'::jsonb;
  r RECORD;
BEGIN
  FOR r IN SELECT key, value, value_type FROM public.app_config LOOP
    result := result || jsonb_build_object(r.key,
      CASE r.value_type
        WHEN 'bool' THEN to_jsonb(r.value = 'true')
        WHEN 'int'  THEN to_jsonb(r.value::int)
        WHEN 'json' THEN r.value::jsonb
        ELSE         to_jsonb(r.value)
      END
    );
  END LOOP;
  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_app_config_map() TO anon, authenticated, service_role;

-- ── Grants ────────────────────────────────────────────────────
GRANT ALL ON public.app_config TO anon, authenticated, service_role;
