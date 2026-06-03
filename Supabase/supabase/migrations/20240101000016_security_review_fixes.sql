-- ============================================================
-- Migration 014: Security review fixes
--
-- A háromirányú review (kód · Supabase · biztonság) során feltárt
-- DB-szintű hibák javítása. Idempotens – futtatható a meglévő remote-on
-- (supabase db push) és friss telepítésnél is.
-- ============================================================

-- ── FIX 1 (KRITIKUS): user_profiles.role self-escalation ────────────
-- A user_profiles UPDATE policy USING (auth.uid() = id) WITH CHECK és
-- oszlop-korlát nélkül, miközben az `authenticated` table-level UPDATE-tel
-- rendelkezik → a user a saját során role='admin'-t írhat és teljes admin
-- hozzáférést szerez. Javítás: BEFORE UPDATE trigger, ami csak admin vagy
-- service_role (auth.uid() IS NULL) számára engedi a role módosítását.
CREATE OR REPLACE FUNCTION public.guard_user_profile_role()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN
      RAISE EXCEPTION 'Role change not allowed';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_user_profile_role_trigger ON public.user_profiles;
CREATE TRIGGER guard_user_profile_role_trigger
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_user_profile_role();


-- ── FIX 2: app_config – GRANT ALL TO anon visszavonása ──────────────
-- A 007 a 004 hardening UTÁN fut, így az app_config-on megmaradt a
-- GRANT ALL TO anon. RLS blokkol, de ez sérti a least-privilege elvet.
REVOKE ALL ON public.app_config FROM anon;
GRANT SELECT ON public.app_config TO anon;


-- ── FIX 3: cleanup_old_resource_snapshots – mutable search_path ─────
-- SECURITY DEFINER függvény SET search_path nélkül = privilege-escalation
-- felület. Csak a search_path-ot rögzítjük, a törzs változatlan.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'cleanup_old_resource_snapshots'
  ) THEN
    ALTER FUNCTION public.cleanup_old_resource_snapshots() SET search_path = public;
  END IF;
END $$;


-- ── FIX 4: audit_log tábla ──────────────────────────────────────────
-- A translate-language edge function audit_log-ba ír, de a tábla sosem
-- jött létre → minden futásnál hiba. Létrehozzuk, admin-only olvasással.
CREATE TABLE IF NOT EXISTS public.audit_log (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  action        TEXT NOT NULL,
  actor_id      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email   TEXT,
  actor_role    TEXT,
  target_table  TEXT,
  details       JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS audit_log_created_at_idx ON public.audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_action_idx     ON public.audit_log(action);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'audit_log'
      AND policyname = 'Admins read audit_log'
  ) THEN
    CREATE POLICY "Admins read audit_log"
      ON public.audit_log FOR SELECT TO authenticated
      USING (public.is_admin(auth.uid()));
  END IF;
END $$;

-- Csak a service_role írhat (edge function-ök); anon/authenticated nem.
REVOKE ALL ON public.audit_log FROM anon, authenticated;
GRANT SELECT ON public.audit_log TO authenticated;
GRANT ALL ON public.audit_log TO service_role;
