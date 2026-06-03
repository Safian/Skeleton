-- ============================================================
-- Migration 012: Hiányzó táblák – translations, legal_documents
-- ============================================================

-- ── translations ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.translations (
  key        TEXT PRIMARY KEY,
  hu         TEXT NOT NULL DEFAULT '',
  locales    JSONB NOT NULL DEFAULT '{}'
);

ALTER TABLE public.translations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read translations"
  ON public.translations FOR SELECT
  USING (true);

CREATE POLICY "Admins manage translations"
  ON public.translations FOR ALL
  USING (public.is_admin(auth.uid()));

GRANT SELECT ON public.translations TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.translations TO authenticated;
GRANT ALL ON public.translations TO service_role;

-- ── legal_documents ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.legal_documents (
  id              TEXT NOT NULL,
  version         TEXT NOT NULL DEFAULT '1.0',
  is_active       BOOLEAN NOT NULL DEFAULT true,
  title_locales   JSONB NOT NULL DEFAULT '{}',
  content_locales JSONB NOT NULL DEFAULT '{}',
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, version)
);

ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read active legal_documents"
  ON public.legal_documents FOR SELECT
  USING (is_active = true);

CREATE POLICY "Admins manage legal_documents"
  ON public.legal_documents FOR ALL
  USING (public.is_admin(auth.uid()));

GRANT SELECT ON public.legal_documents TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.legal_documents TO authenticated;
GRANT ALL ON public.legal_documents TO service_role;

-- ── user_sessions: email a user_profiles-ból ─────────────────
-- Az auth.users tábla nem érhető el PostgREST foreign key join-nal.
-- A user_profiles.email mezőt kell használni helyette.
-- Nincs szükség sémamódosításra – a Flutter kódot kell javítani.
