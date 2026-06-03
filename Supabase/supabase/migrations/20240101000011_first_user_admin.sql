-- ============================================================
-- Migration 011: Első felhasználó automatikusan admin
-- ============================================================

-- Módosított trigger: ha még nincs user_profile, az első beregisztrált
-- automatikusan 'admin' role-t kap.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.user_profiles;

  INSERT INTO public.user_profiles (id, email, role)
  VALUES (
    NEW.id,
    NEW.email,
    CASE WHEN v_count = 0 THEN 'admin' ELSE 'user' END
  );
  RETURN NEW;
END;
$$;

-- Publikus RPC: megmondja az appnak, hogy ez az első indítás-e
-- (anon is hívhatja, nincs érzékeny adat)
CREATE OR REPLACE FUNCTION public.is_first_setup()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NOT EXISTS (SELECT 1 FROM public.user_profiles LIMIT 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_first_setup() TO anon, authenticated, service_role;

-- ── Email megerősítés kikapcsolása ─────────────────────────────────
-- Egységes a config.toml [auth.email] enable_confirmations = false beállítással,
-- és felülírja a remote dashboard esetleges "Confirm email" kapcsolóját is.
-- Minden új user automatikusan megerősített email címet kap, és a már létező,
-- meg nem erősített felhasználók is megerősítésre kerülnek.
--
-- FIGYELEM (biztonság): ha az appban engedélyezett a self-registration, ez azt
-- jelenti, hogy bárki azonnal aktív fiókot hozhat létre email-tulajdon igazolása
-- nélkül. Az admin app nem enged regisztrációt; a client app igen – ott ez
-- tudatos kompromisszum (lásd TODO). Production self-signup esetén fontold meg
-- a kikapcsolását.
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE email_confirmed_at IS NULL;

CREATE OR REPLACE FUNCTION public.auto_confirm_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email_confirmed_at IS NULL THEN
    NEW.email_confirmed_at := now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_confirm_email_trigger ON auth.users;
CREATE TRIGGER auto_confirm_email_trigger
  BEFORE INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.auto_confirm_email();
