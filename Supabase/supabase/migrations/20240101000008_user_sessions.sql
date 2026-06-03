-- ============================================================
-- Migration 008: User Sessions – Bejelentkezési metaadat naplózás [M6]
-- ============================================================

-- ── user_sessions ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Eszköz adatok
  device_model    TEXT,       -- pl. 'iPhone 15 Pro', 'Samsung Galaxy S24'
  device_brand    TEXT,       -- pl. 'Apple', 'Samsung'
  os_name         TEXT,       -- pl. 'iOS', 'Android'
  os_version      TEXT,       -- pl. '17.4', '14'
  app_version     TEXT,       -- pl. '1.2.3'
  app_build       TEXT,       -- pl. '42'
  locale          TEXT,       -- pl. 'hu_HU', 'en_US'

  -- Geo / hálózat (IP-ből levezetett)
  ip_address      INET,
  geo_country     TEXT,       -- pl. 'Hungary'
  geo_city        TEXT,       -- pl. 'Budapest'
  geo_lat         NUMERIC(9,6),
  geo_lon         NUMERIC(9,6),

  -- Session állapot
  is_active       BOOLEAN NOT NULL DEFAULT true,
  last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at      TIMESTAMPTZ,
  revoked_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Supabase auth session hivatkozás (opcionális)
  supabase_session_id TEXT
);

-- Indexek
CREATE INDEX IF NOT EXISTS user_sessions_user_id_idx     ON public.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS user_sessions_is_active_idx   ON public.user_sessions(is_active);
CREATE INDEX IF NOT EXISTS user_sessions_created_at_idx  ON public.user_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS user_sessions_last_seen_idx   ON public.user_sessions(last_seen_at DESC);

-- FK a user_profiles-ra is – szükséges a PostgREST embeddinghez:
--   .select('*, user_profiles!user_id(display_name, email)')
-- (a user_id egyúttal auth.users-re is mutat, lásd fent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_sessions_user_id_fk'
  ) THEN
    ALTER TABLE public.user_sessions
      ADD CONSTRAINT user_sessions_user_id_fk
      FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

-- Saját session-ök láthatók
CREATE POLICY "Users can read own sessions"
  ON public.user_sessions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Adminok mindent látnak
CREATE POLICY "Admins can read all sessions"
  ON public.user_sessions FOR SELECT
  TO authenticated
  USING (public.is_admin(auth.uid()));

-- Adminok frissíthetnek (revoke)
CREATE POLICY "Admins can update sessions"
  ON public.user_sessions FOR UPDATE
  TO authenticated
  USING (public.is_admin(auth.uid()));

-- Felhasználók visszavonhatják saját session-jüket
CREATE POLICY "Users can revoke own sessions"
  ON public.user_sessions FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- Service role teljes hozzáférés (edge function logoláshoz)
CREATE POLICY "Service role full access sessions"
  ON public.user_sessions FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- ── RPC: revoke_session ────────────────────────────────────────
-- Visszavonja az adott session-t (admin vagy saját)
CREATE OR REPLACE FUNCTION public.revoke_session(session_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Csak admin vagy saját session-t lehet visszavonni
  IF NOT (
    public.is_admin(auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_sessions
            WHERE id = session_id AND user_id = auth.uid())
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  UPDATE public.user_sessions
  SET
    is_active   = false,
    revoked_at  = now(),
    revoked_by  = auth.uid()
  WHERE id = session_id;
END;
$$;

-- ── RPC: get_session_stats ─────────────────────────────────────
-- Aggregált statisztikák admin dashboardhoz
CREATE OR REPLACE FUNCTION public.get_session_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT jsonb_build_object(
    'total_sessions',    COUNT(*),
    'active_sessions',   COUNT(*) FILTER (WHERE is_active = true),
    'sessions_today',    COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours'),
    'unique_users',      COUNT(DISTINCT user_id),
    -- Eszközök megoszlása
    'os_breakdown', (
      SELECT jsonb_object_agg(os_name, cnt)
      FROM (
        SELECT COALESCE(os_name, 'Unknown') as os_name, COUNT(*) as cnt
        FROM public.user_sessions
        GROUP BY os_name
        ORDER BY cnt DESC
        LIMIT 10
      ) t
    ),
    -- App verziók megoszlása
    'version_breakdown', (
      SELECT jsonb_object_agg(app_version, cnt)
      FROM (
        SELECT COALESCE(app_version, 'Unknown') as app_version, COUNT(*) as cnt
        FROM public.user_sessions
        WHERE is_active = true
        GROUP BY app_version
        ORDER BY cnt DESC
        LIMIT 10
      ) t
    )
  )
  INTO result
  FROM public.user_sessions;

  RETURN result;
END;
$$;
