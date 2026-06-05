-- ============================================================
-- Migration 019 – Deferred Deep Linking  [M2.4]
--
-- pending_invites tábla: webes meghívó link IP-alapú egyeztetés
-- az app első indításakor.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.pending_invites (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token        TEXT NOT NULL UNIQUE,           -- az /invite?token=XYZ értéke
  client_ip    INET,                           -- a webes redirect előtt rögzített IP
  metadata     JSONB NOT NULL DEFAULT '{}',   -- user-agent, referer stb.
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  matched_at   TIMESTAMPTZ,                   -- mikor egyezett be az app
  is_used      BOOLEAN NOT NULL DEFAULT false,
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '1 hour')
);

CREATE INDEX IF NOT EXISTS pending_invites_ip_idx
  ON public.pending_invites (client_ip, expires_at)
  WHERE is_used = false;

CREATE INDEX IF NOT EXISTS pending_invites_token_idx
  ON public.pending_invites (token);

ALTER TABLE public.pending_invites ENABLE ROW LEVEL SECURITY;

-- Csak service_role írhat/olvashat (az Edge Functions service_role-lal futnak)
CREATE POLICY "Service role manages pending_invites"
  ON public.pending_invites FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- Anon nem fér hozzá közvetlenül (az Edge Function kezeli)
REVOKE ALL ON public.pending_invites FROM anon;
REVOKE ALL ON public.pending_invites FROM authenticated;
GRANT ALL   ON public.pending_invites TO service_role;

-- Automatikus karbantartás: 24 óránál régebbi lejárt bejegyzések törlése
CREATE OR REPLACE FUNCTION public.cleanup_expired_pending_invites()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.pending_invites
  WHERE expires_at < now() - INTERVAL '24 hours';
END;
$$;
