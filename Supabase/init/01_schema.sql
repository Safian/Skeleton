-- ============================================================
-- 01_schema.sql – Skeleton app adatbázis séma
-- (user_profiles + items + triggerek + RLS)
-- ============================================================

-- ── user_profiles ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT NOT NULL,
  display_name  TEXT,
  avatar_url    TEXT,
  role          TEXT NOT NULL DEFAULT 'user',
  language      TEXT NOT NULL DEFAULT 'hu',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Helper to check if a user is an admin (SECURITY DEFINER to avoid RLS infinite recursion)
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = user_id AND role = 'admin'
  );
END;
$$;

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.user_profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON public.user_profiles FOR SELECT
  USING (public.is_admin(auth.uid()));

CREATE POLICY "Admins can update all profiles"
  ON public.user_profiles FOR UPDATE
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Admins can delete profiles"
  ON public.user_profiles FOR DELETE
  USING (public.is_admin(auth.uid()));

-- ── items ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  description   TEXT,
  category      TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS items_user_id_idx    ON public.items(user_id);
CREATE INDEX IF NOT EXISTS items_created_at_idx ON public.items(created_at DESC);

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own items"
  ON public.items FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all items"
  ON public.items FOR ALL
  USING (public.is_admin(auth.uid()));

-- ── updated_at trigger ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_user_profile_updated
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER on_item_updated
  BEFORE UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ── Regisztrációkor auto profil ───────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, role, language)
  VALUES (NEW.id, NEW.email, 'user', COALESCE(NEW.raw_user_meta_data->>'language', 'hu'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── Bootstrap first admin trigger ────────────────────────────
-- Ha nincs admin: az első regisztrált user automatikusan admin lesz.
-- Ha már van admin: a trigger törli magát (soha nem fut le újra).
CREATE OR REPLACE FUNCTION public.handle_first_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_count INT;
BEGIN
  SELECT COUNT(*) INTO v_admin_count
  FROM public.user_profiles
  WHERE role = 'admin';

  IF v_admin_count = 0 THEN
    UPDATE public.user_profiles SET role = 'admin' WHERE id = NEW.id;
  ELSE
    EXECUTE 'DROP TRIGGER IF EXISTS bootstrap_first_admin_trigger ON public.user_profiles';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bootstrap_first_admin_trigger ON public.user_profiles;
CREATE TRIGGER bootstrap_first_admin_trigger
  AFTER INSERT ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_first_admin();

-- ── translations ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.translations (
  key      TEXT PRIMARY KEY,
  hu       TEXT NOT NULL DEFAULT '',
  en       TEXT NOT NULL DEFAULT '',
  locales  JSONB NOT NULL DEFAULT '{}'
);

ALTER TABLE public.translations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read translations" ON public.translations
  FOR SELECT TO public USING (true);

CREATE POLICY "Admins manage translations" ON public.translations
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- ── legal_documents ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.legal_documents (
  id              TEXT NOT NULL,
  version         TEXT NOT NULL DEFAULT '1.0',
  is_active       BOOLEAN NOT NULL DEFAULT true,
  title_locales   JSONB NOT NULL DEFAULT '{}',
  content_locales JSONB NOT NULL DEFAULT '{}',
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, version)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_legal_documents_active_id ON public.legal_documents (id) WHERE (is_active = true);

ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read legal_documents" ON public.legal_documents
  FOR SELECT TO public USING (true);

CREATE POLICY "Admins manage legal_documents" ON public.legal_documents
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Alapértelmezett ÁSZF és Adatvédelmi Nyilatkozat
INSERT INTO public.legal_documents (id, version, is_active, title_locales, content_locales)
VALUES
  (
    'terms',
    '1.0',
    true,
    '{
      "hu": "Általános Szerződési Feltételek",
      "en": "Terms of Service",
      "de": "Allgemeine Geschäftsbedingungen"
    }',
    '{
      "hu": "<div align=\"center\"><font size=\"20\"><b>Általános Szerződési Feltételek</b></font></div><br/><br/>Üdvözöljük a Skeleton platformon! A szolgáltatás használatával Ön elfogadja a jelen feltételeket.<br/><br/><b>1. Szolgáltatás leírása:</b> Ez egy többnyelvű Flutter sablonalkalmazás.<br/><b>2. Regisztráció:</b> Regisztrációra bárki jogosult.<br/><b>3. Felelősség:</b> A szolgáltatást mindenki a saját felelősségére használja.",
      "en": "<div align=\"center\"><font size=\"20\"><b>Terms of Service</b></font></div><br/><br/>Welcome to Skeleton! By using our service, you agree to these terms.<br/><br/><b>1. Service Description:</b> This is a multilingual Flutter skeleton application.<br/><b>2. Registration:</b> Anyone is eligible to register.<br/><b>3. Liability:</b> The service is provided \"as is\" and used at your own risk.",
      "de": "<div align=\"center\"><font size=\"20\"><b>Allgemeine Geschäftsbedingungen</b></font></div><br/><br/>Willkommen bei Skeleton! Durch die Nutzung unseres Dienstes stimmen Sie diesen Bedingungen zu.<br/><br/><b>1. Leistungsbeschreibung:</b> Dies ist eine mehrsprachige Flutter-Skeleton-Anwendung.<br/><b>2. Registrierung:</b> Jeder ist zur Registrierung berechtigt."
    }'
  ),
  (
    'privacy',
    '1.0',
    true,
    '{
      "hu": "Adatvédelmi Nyilatkozat",
      "en": "Privacy Policy",
      "de": "Datenschutzerklärung"
    }',
    '{
      "hu": "<div align=\"center\"><font size=\"20\"><b>Adatvédelmi Nyilatkozat</b></font></div><br/><br/>Az Ön adatainak védelme kiemelten fontos számunkra.<br/><br/><b>1. Gyűjtött adatok:</b> Kapcsolattartási adatok (email), megjelenítendő név.<br/><b>2. Adatkezelés célja:</b> A szolgáltatás biztosítása.<br/><b>3. GDPR jogok:</b> Bármikor kérheti adatai törlését vagy módosítását.",
      "en": "<div align=\"center\"><font size=\"20\"><b>Privacy Policy</b></font></div><br/><br/>Your privacy is of utmost importance to us.<br/><br/><b>1. Collected Data:</b> Contact data (email), display name.<br/><b>2. Purpose:</b> Providing the service.<br/><b>3. GDPR Rights:</b> You can request account deletion at any time in settings.",
      "de": "<div align=\"center\"><font size=\"20\"><b>Datenschutzerklärung</b></font></div><br/><br/>Der Schutz Ihrer Daten ist uns sehr wichtig.<br/><br/><b>1. Erhobene Daten:</b> E-Mail-Adresse, Anzeigename.<br/><b>2. Zweck:</b> Bereitstellung des Dienstes."
    }'
  )
ON CONFLICT (id, version) DO NOTHING;

-- ── Jogosultságok (least-privilege) ───────────────────────────
-- FONTOS: soha ne adj GRANT ALL-t az anon role-nak – az RLS az egyetlen
-- védelem, és egyetlen elnézett policy = anonim írás minden táblán.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- authenticated: teljes CRUD (a sorszintű hozzáférést az RLS korlátozza)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- service_role: minden (megkerüli az RLS-t; csak szerver oldalon használt)
GRANT ALL ON ALL TABLES    IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL ROUTINES  IN SCHEMA public TO service_role;

-- anon: KIZÁRÓLAG olvasás, és csak a publikus tartalom-táblákon
-- (user_profiles / items nem érhető el anonim módon).
GRANT SELECT ON public.translations    TO anon;
GRANT SELECT ON public.legal_documents TO anon;
