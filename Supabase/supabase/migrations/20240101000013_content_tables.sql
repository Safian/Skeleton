-- ============================================================
-- Migration 013: Tartalom táblák végleges sémája
-- translations (en oszlop hozzáadva), legal_documents
-- Ezek a skeleton alapcsomaghoz tartoznak, ne töröld!
-- ============================================================

-- ── translations ─────────────────────────────────────────────
-- key: egyedi azonosító (pl. "home.title")
-- hu:  magyar szöveg
-- en:  angol szöveg (külön oszlop a gyors hozzáférésért)
-- locales: JSONB – további nyelvek {"de": "...", "fr": "..."}

CREATE TABLE IF NOT EXISTS public.translations (
  key     TEXT PRIMARY KEY,
  hu      TEXT NOT NULL DEFAULT '',
  en      TEXT NOT NULL DEFAULT '',
  locales JSONB NOT NULL DEFAULT '{}'
);

-- en oszlop hozzáadása ha a tábla már létezik (012-ből)
ALTER TABLE public.translations ADD COLUMN IF NOT EXISTS en TEXT NOT NULL DEFAULT '';

ALTER TABLE public.translations ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Public read translations" ON public.translations FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admins manage translations" ON public.translations FOR ALL USING (public.is_admin(auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

GRANT SELECT ON public.translations TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.translations TO authenticated;
GRANT ALL ON public.translations TO service_role;

-- ── legal_documents ───────────────────────────────────────────
-- ÁSZF, adatvédelmi nyilatkozat stb. – lokalizált HTML tartalom.
-- id: dokumentum típusa (pl. "terms", "privacy")
-- version: verziószám (pl. "1.0")
-- title_locales / content_locales: JSONB {"hu": "...", "en": "..."}

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

DO $$ BEGIN
  CREATE POLICY "Public read active legal_documents" ON public.legal_documents FOR SELECT USING (is_active = true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Admins manage legal_documents" ON public.legal_documents FOR ALL USING (public.is_admin(auth.uid()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

GRANT SELECT ON public.legal_documents TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.legal_documents TO authenticated;
GRANT ALL ON public.legal_documents TO service_role;
