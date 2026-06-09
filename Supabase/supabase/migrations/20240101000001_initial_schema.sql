-- ============================================================
-- Konszolidált initiális migráció
-- Tartalmaz: user_profiles, items, admin features, security,
--            invitations, pending_invites, app config, sessions,
--            backups, bug reports, translations, legal docs,
--            audit log, realtime publication
-- ============================================================

-- ════════════════════════════════════════════════════════════
-- 1. HELPER FÜGGVÉNYEK (triggerek/policy-k előtt kell)
-- ════════════════════════════════════════════════════════════

-- updated_at automatikus frissítése
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Admin check – SECURITY DEFINER hogy ne okozzon RLS rekurziót
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles WHERE id = user_id AND role = 'admin'
  );
END;
$$;

-- Regisztrációkor auto profil (language a user meta adatból)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, role, language)
  VALUES (
    NEW.id,
    NEW.email,
    'user',
    COALESCE(NEW.raw_user_meta_data->>'language', 'hu')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Első admin bootstrap: ha még nincs admin, az első user_profiles INSERT kap admin role-t.
-- Ha már van admin, a trigger törli magát (soha nem fut le újra).
CREATE OR REPLACE FUNCTION public.handle_first_admin()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_admin_count INT;
BEGIN
  SELECT COUNT(*) INTO v_admin_count FROM public.user_profiles WHERE role = 'admin';
  IF v_admin_count = 0 THEN
    UPDATE public.user_profiles SET role = 'admin' WHERE id = NEW.id;
  ELSE
    EXECUTE 'DROP TRIGGER IF EXISTS bootstrap_first_admin_trigger ON public.user_profiles';
  END IF;
  RETURN NEW;
END;
$$;

-- Email megerősítés automatikus kiosztása (opcionális – config.toml-lal együtt)
CREATE OR REPLACE FUNCTION public.auto_confirm_email()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.email_confirmed_at IS NULL THEN
    NEW.email_confirmed_at := now();
  END IF;
  RETURN NEW;
END;
$$;

-- Role self-escalation védelme
CREATE OR REPLACE FUNCTION public.guard_user_profile_role()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN
      RAISE EXCEPTION 'Role change not allowed';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Egyszerre csak egy default AI modell
CREATE OR REPLACE FUNCTION public.handle_ai_model_single_default()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE public.ai_models SET is_default = false WHERE id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

-- Admin cost stats (admin-only)
CREATE OR REPLACE FUNCTION public.get_admin_cost_stats()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_today_start  TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'UTC');
  v_month_start  TIMESTAMPTZ := date_trunc('month', NOW() AT TIME ZONE 'UTC');
  v_gpt_today    NUMERIC := 0;
  v_gpt_month    NUMERIC := 0;
  v_in_tokens    BIGINT  := 0;
  v_out_tokens   BIGINT  := 0;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission denied: admin role required' USING ERRCODE = '42501';
  END IF;
  SELECT
    COALESCE(SUM(CASE WHEN created_at >= v_today_start THEN cost_usd ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN created_at >= v_month_start THEN cost_usd ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN created_at >= v_month_start THEN input_tokens  ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN created_at >= v_month_start THEN output_tokens ELSE 0 END), 0)
  INTO v_gpt_today, v_gpt_month, v_in_tokens, v_out_tokens
  FROM public.gpt_usage_logs;
  RETURN json_build_object(
    'gpt_cost_today',      v_gpt_today,
    'gpt_cost_month',      v_gpt_month,
    'total_cost_today',    v_gpt_today,
    'total_cost_month',    v_gpt_month,
    'input_tokens_month',  v_in_tokens,
    'output_tokens_month', v_out_tokens
  );
END;
$$;

-- Security log lezárása
CREATE OR REPLACE FUNCTION public.resolve_security_log(log_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Access denied'; END IF;
  UPDATE public.security_logs
  SET is_resolved = true, resolved_at = now(), resolved_by = auth.uid()
  WHERE id = log_id;
END;
$$;

-- Security statisztikák
CREATE OR REPLACE FUNCTION public.get_security_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result jsonb;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Access denied'; END IF;
  SELECT jsonb_build_object(
    'total_events',      COUNT(*),
    'unresolved_events', COUNT(*) FILTER (WHERE NOT is_resolved),
    'events_today',      COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours'),
    'brute_force_count', COUNT(*) FILTER (WHERE event_type = 'brute_force' AND NOT is_resolved),
    'ssh_login_count',   COUNT(*) FILTER (WHERE event_type = 'successful_ssh_login' AND created_at >= now() - interval '24 hours'),
    'active_bans',       (SELECT COUNT(*) FROM public.banned_ips WHERE is_active = true),
    'top_attacker_ip',   (
      SELECT ip_address::text FROM public.security_logs
      WHERE event_type = 'brute_force' AND created_at >= now() - interval '7 days'
      GROUP BY ip_address ORDER BY COUNT(*) DESC LIMIT 1
    )
  ) INTO result FROM public.security_logs;
  RETURN result;
END;
$$;

-- Meghívó token validálás (anon is hívhatja)
CREATE OR REPLACE FUNCTION public.validate_invitation_token(p_token UUID)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_inv RECORD;
BEGIN
  SELECT * INTO v_inv FROM public.admin_invitations WHERE token = p_token;
  IF NOT FOUND     THEN RETURN jsonb_build_object('valid', false, 'reason', 'not_found');    END IF;
  IF v_inv.is_used THEN RETURN jsonb_build_object('valid', false, 'reason', 'already_used'); END IF;
  IF v_inv.expires_at < now() THEN RETURN jsonb_build_object('valid', false, 'reason', 'expired'); END IF;
  RETURN jsonb_build_object('valid', true, 'email', v_inv.email, 'role', v_inv.role, 'id', v_inv.id);
END;
$$;

-- App config map (anon is hívhatja – app induláskor)
CREATE OR REPLACE FUNCTION public.get_app_config_map()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result jsonb := '{}'::jsonb; r RECORD;
BEGIN
  FOR r IN SELECT key, value, value_type FROM public.app_config LOOP
    result := result || jsonb_build_object(r.key,
      CASE r.value_type
        WHEN 'bool' THEN to_jsonb(r.value = 'true')
        WHEN 'int'  THEN to_jsonb(r.value::int)
        WHEN 'json' THEN r.value::jsonb
        ELSE             to_jsonb(r.value)
      END
    );
  END LOOP;
  RETURN result;
END;
$$;

-- Session visszavonás
CREATE OR REPLACE FUNCTION public.revoke_session(session_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT (
    public.is_admin(auth.uid()) OR
    EXISTS (SELECT 1 FROM public.user_sessions WHERE id = session_id AND user_id = auth.uid())
  ) THEN RAISE EXCEPTION 'Access denied'; END IF;
  UPDATE public.user_sessions
  SET is_active = false, revoked_at = now(), revoked_by = auth.uid()
  WHERE id = session_id;
END;
$$;

-- Session statisztikák
CREATE OR REPLACE FUNCTION public.get_session_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result jsonb;
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Access denied'; END IF;
  SELECT jsonb_build_object(
    'total_sessions',    COUNT(*),
    'active_sessions',   COUNT(*) FILTER (WHERE is_active = true),
    'sessions_today',    COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours'),
    'unique_users',      COUNT(DISTINCT user_id),
    'os_breakdown', (
      SELECT jsonb_object_agg(os_name, cnt) FROM (
        SELECT COALESCE(os_name, 'Unknown') as os_name, COUNT(*) as cnt
        FROM public.user_sessions GROUP BY os_name ORDER BY cnt DESC LIMIT 10
      ) t
    ),
    'version_breakdown', (
      SELECT jsonb_object_agg(app_version, cnt) FROM (
        SELECT COALESCE(app_version, 'Unknown') as app_version, COUNT(*) as cnt
        FROM public.user_sessions WHERE is_active = true
        GROUP BY app_version ORDER BY cnt DESC LIMIT 10
      ) t
    )
  ) INTO result FROM public.user_sessions;
  RETURN result;
END;
$$;

-- Lejárt pending_invites törlése (24h-nál régebbiek)
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

-- Resource snapshot cleanup (SET search_path rögzítve – security hardening)
CREATE OR REPLACE FUNCTION public.cleanup_old_resource_snapshots()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM public.resource_snapshots WHERE recorded_at < now() - interval '24 hours';
END;
$$;

-- Bug státusz frissítés
CREATE OR REPLACE FUNCTION public.update_bug_status(p_bug_id UUID, p_status TEXT, p_notes TEXT DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN RAISE EXCEPTION 'Access denied'; END IF;
  IF p_status NOT IN ('open', 'in_progress', 'resolved', 'wont_fix') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;
  UPDATE public.bug_reports SET
    status      = p_status,
    admin_notes = COALESCE(p_notes, admin_notes),
    resolved_at = CASE WHEN p_status IN ('resolved', 'wont_fix') THEN now() ELSE resolved_at END,
    assigned_to = CASE WHEN p_status = 'in_progress' THEN auth.uid() ELSE assigned_to END
  WHERE id = p_bug_id;
END;
$$;

-- Első setup check (anon is hívhatja)
CREATE OR REPLACE FUNCTION public.is_first_setup()
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN NOT EXISTS (SELECT 1 FROM public.user_profiles LIMIT 1);
END;
$$;


-- ════════════════════════════════════════════════════════════
-- 2. TÁBLÁK (dependency sorrend)
-- ════════════════════════════════════════════════════════════

-- ── user_profiles ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email        TEXT NOT NULL,
  display_name TEXT,
  avatar_url   TEXT,
  role         TEXT NOT NULL DEFAULT 'user',
  language     TEXT NOT NULL DEFAULT 'hu',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"       ON public.user_profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"     ON public.user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles"     ON public.user_profiles FOR SELECT USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins can update all profiles"   ON public.user_profiles FOR UPDATE
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Admins can delete profiles"       ON public.user_profiles FOR DELETE USING (public.is_admin(auth.uid()));

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS auto_confirm_email_trigger ON auth.users;
CREATE TRIGGER auto_confirm_email_trigger
  BEFORE INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.auto_confirm_email();

CREATE TRIGGER on_user_profile_updated
  BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS guard_user_profile_role_trigger ON public.user_profiles;
CREATE TRIGGER guard_user_profile_role_trigger
  BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.guard_user_profile_role();

DROP TRIGGER IF EXISTS bootstrap_first_admin_trigger ON public.user_profiles;
CREATE TRIGGER bootstrap_first_admin_trigger
  AFTER INSERT ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION public.handle_first_admin();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_profiles TO authenticated;
GRANT ALL ON public.user_profiles TO service_role;

-- Meglévő, meg nem erősített user-ek javítása
UPDATE auth.users SET email_confirmed_at = COALESCE(email_confirmed_at, now()) WHERE email_confirmed_at IS NULL;


-- ── items ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT,
  category    TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS items_user_id_idx    ON public.items(user_id);
CREATE INDEX IF NOT EXISTS items_created_at_idx ON public.items(created_at DESC);

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own items" ON public.items FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all items" ON public.items FOR ALL
  USING (public.is_admin(auth.uid()));

CREATE TRIGGER on_item_updated
  BEFORE UPDATE ON public.items FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

GRANT SELECT, INSERT, UPDATE, DELETE ON public.items TO authenticated;
GRANT ALL ON public.items TO service_role;


-- ── app_settings ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_settings (
  id          TEXT PRIMARY KEY,
  value       TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT ''
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage app_settings" ON public.app_settings FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;

INSERT INTO public.app_settings (id, value, description) VALUES
  ('daily_api_cost_limit',      '5.0',  'Globális napi API költségkorlát USD-ben.'),
  ('firebase_service_account_json', '', 'Google Firebase Service Account JSON a push értesítésekhez.'),
  ('firebase_vapid_key',        '',     'Web Push VAPID kulcs.'),
  ('security_webhook_api_key',  '',     'Az /api/v1/security/alert endpoint Bearer API kulcsa.'),
  ('telegram_bot_token',        '',     'Telegram Bot API token a riasztásokhoz.'),
  ('telegram_chat_id',          '',     'Telegram Chat ID ahova a riasztások mennek.'),
  ('discord_webhook_url',       '',     'Discord Webhook URL (alternatíva Telegram helyett).'),
  ('unban_webhook_url',         '',     'A szerveren futó unban endpoint URL-je (pl. http://VPS_IP:9090/unban).'),
  ('backup_webhook_url',        '',     'A szerveren futó backup trigger endpoint URL-je (pl. http://VPS_IP:9091/backup).'),
  ('backup_webhook_secret',     '',     'Backup webhook autentikációs secret (X-Backup-Secret header).'),
  ('smtp_from_email',           '',     'Feladó e-mail cím (pl. noreply@sajatdomain.com).'),
  ('smtp_from_name',            'Admin','Feladó megjelenített neve.'),
  ('app_base_url',              '',     'Az app alap URL-je a meghívó linkhez (pl. https://app.sajatdomain.com).'),
  ('resend_api_key',            '',     'Resend.com API kulcs az e-mail küldéshez.'),
  ('mailgun_api_key',           '',     'Mailgun API kulcs (alternatíva Resend helyett).'),
  ('mailgun_domain',            '',     'Mailgun domain (pl. mail.sajatdomain.com).'),
  ('s3_endpoint',               '',     'S3 endpoint URL.'),
  ('s3_bucket',                 '',     'S3 bucket neve a backupokhoz.'),
  ('s3_access_key',             '',     'S3 access key ID.'),
  ('s3_secret_key',             '',     'S3 secret access key.'),
  ('s3_region',                 'eu-central-1', 'S3 region.'),
  ('backup_encryption_key',     '',     'GPG/OpenSSL titkosítási kulcs a backupokhoz.'),
  ('disk_alert_threshold',      '85',   'Tárhely riasztás küszöb százalékban.'),
  ('ram_alert_threshold',       '90',   'RAM riasztás küszöb százalékban.')
ON CONFLICT (id) DO NOTHING;


-- ── ai_models ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ai_models (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  model         TEXT NOT NULL,
  system_prompt TEXT,
  is_default    BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.ai_models ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage ai_models" ON public.ai_models FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access ai_models" ON public.ai_models FOR ALL TO service_role
  USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_single_ai_model_default ON public.ai_models;
CREATE TRIGGER trg_single_ai_model_default
  AFTER INSERT OR UPDATE ON public.ai_models FOR EACH ROW EXECUTE FUNCTION public.handle_ai_model_single_default();

INSERT INTO public.ai_models (name, model, is_default, system_prompt)
VALUES ('GPT-4o Mini', 'gpt-4o-mini', true, null)
ON CONFLICT DO NOTHING;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_models TO authenticated;
GRANT ALL ON public.ai_models TO service_role;


-- ── gpt_usage_logs ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.gpt_usage_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  model         TEXT NOT NULL,
  input_tokens  INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd      NUMERIC(10,6) NOT NULL DEFAULT 0,
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_gpt_usage_logs_created_at ON public.gpt_usage_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gpt_usage_logs_user_id    ON public.gpt_usage_logs(user_id);

ALTER TABLE public.gpt_usage_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read gpt_usage_logs" ON public.gpt_usage_logs FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access gpt_logs" ON public.gpt_usage_logs FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.gpt_usage_logs TO authenticated;
GRANT ALL ON public.gpt_usage_logs TO service_role;


-- ── app_error_logs ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_error_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  app           TEXT NOT NULL DEFAULT 'app',
  user_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  error_type    TEXT NOT NULL,
  error_message TEXT NOT NULL,
  context       JSONB DEFAULT '{}',
  stack_trace   TEXT
);

CREATE INDEX IF NOT EXISTS idx_app_error_logs_created_at ON public.app_error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_error_logs_app        ON public.app_error_logs(app);
CREATE INDEX IF NOT EXISTS idx_app_error_logs_error_type ON public.app_error_logs(error_type);

ALTER TABLE public.app_error_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read app_error_logs" ON public.app_error_logs FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));
CREATE POLICY "Authenticated users insert own logs" ON public.app_error_logs FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);
CREATE POLICY "Service role full access error_logs" ON public.app_error_logs FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_error_logs TO authenticated;
GRANT ALL ON public.app_error_logs TO service_role;


-- ── user_push_tokens ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  token      TEXT NOT NULL,
  platform   TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_user_token UNIQUE (user_id, token)
);

ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own push tokens" ON public.user_push_tokens FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins read all push tokens" ON public.user_push_tokens FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access push_tokens" ON public.user_push_tokens FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_tokens TO authenticated;
GRANT ALL ON public.user_push_tokens TO service_role;


-- ── push_notification_logs ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.push_notification_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  sender_id      UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  target_group   TEXT NOT NULL,
  target_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,
  status         TEXT NOT NULL,
  error_message  TEXT,
  tokens_count   INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS push_notification_logs_sender_id_idx      ON public.push_notification_logs(sender_id);
CREATE INDEX IF NOT EXISTS push_notification_logs_target_user_id_idx ON public.push_notification_logs(target_user_id);

ALTER TABLE public.push_notification_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage push_notification_logs" ON public.push_notification_logs FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access push_logs" ON public.push_notification_logs FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_notification_logs TO authenticated;
GRANT ALL ON public.push_notification_logs TO service_role;


-- ── security_logs ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  timestamp   TIMESTAMPTZ NOT NULL DEFAULT now(),
  source      TEXT NOT NULL,
  event_type  TEXT NOT NULL,
  ip_address  INET,
  description TEXT,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata    JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS security_logs_created_at_idx  ON public.security_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS security_logs_ip_address_idx  ON public.security_logs(ip_address);
CREATE INDEX IF NOT EXISTS security_logs_event_type_idx  ON public.security_logs(event_type);
CREATE INDEX IF NOT EXISTS security_logs_source_idx      ON public.security_logs(source);
CREATE INDEX IF NOT EXISTS security_logs_is_resolved_idx ON public.security_logs(is_resolved);
CREATE INDEX IF NOT EXISTS security_logs_resolved_by_idx ON public.security_logs(resolved_by);

ALTER TABLE public.security_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read security_logs"   ON public.security_logs FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins can update security_logs" ON public.security_logs FOR UPDATE TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access security_logs" ON public.security_logs FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.security_logs TO authenticated;
GRANT ALL ON public.security_logs TO service_role;


-- ── security_api_keys ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_api_keys (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  key_hash   TEXT NOT NULL UNIQUE,
  is_active  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used  TIMESTAMPTZ
);

ALTER TABLE public.security_api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage security_api_keys" ON public.security_api_keys FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access security_api_keys" ON public.security_api_keys FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.security_api_keys TO authenticated;
GRANT ALL ON public.security_api_keys TO service_role;


-- ── banned_ips ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.banned_ips (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address  INET NOT NULL UNIQUE,
  reason      TEXT,
  jail        TEXT,
  banned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  unbanned_at TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  log_id      UUID REFERENCES public.security_logs(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS banned_ips_ip_address_idx ON public.banned_ips(ip_address);
CREATE INDEX IF NOT EXISTS banned_ips_is_active_idx  ON public.banned_ips(is_active);
CREATE INDEX IF NOT EXISTS banned_ips_log_id_idx     ON public.banned_ips(log_id);

ALTER TABLE public.banned_ips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage banned_ips" ON public.banned_ips FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access banned_ips" ON public.banned_ips FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.banned_ips TO authenticated;
GRANT ALL ON public.banned_ips TO service_role;


-- ── admin_invitations ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_invitations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token      UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  email      TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'admin',
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '48 hours'),
  accepted_at TIMESTAMPTZ,
  is_used    BOOLEAN NOT NULL DEFAULT false,
  note       TEXT
);

CREATE INDEX IF NOT EXISTS admin_invitations_token_idx      ON public.admin_invitations(token);
CREATE INDEX IF NOT EXISTS admin_invitations_email_idx      ON public.admin_invitations(email);
CREATE INDEX IF NOT EXISTS admin_invitations_is_used_idx    ON public.admin_invitations(is_used);
CREATE INDEX IF NOT EXISTS admin_invitations_expires_at_idx ON public.admin_invitations(expires_at);
CREATE INDEX IF NOT EXISTS admin_invitations_invited_by_idx ON public.admin_invitations(invited_by);

ALTER TABLE public.admin_invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage admin_invitations" ON public.admin_invitations FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access admin_invitations" ON public.admin_invitations FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.admin_invitations TO authenticated;
GRANT ALL ON public.admin_invitations TO service_role;


-- ── pending_invites ───────────────────────────────────────────
-- Deferred deep linking: webes meghívó link IP-alapú egyeztetés
-- az app első indításakor. [M2.4]
CREATE TABLE IF NOT EXISTS public.pending_invites (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token      TEXT NOT NULL UNIQUE,           -- az /invite?token=XYZ értéke
  client_ip  INET,                           -- a webes redirect előtt rögzített IP
  metadata   JSONB NOT NULL DEFAULT '{}',    -- user-agent, referer stb.
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  matched_at TIMESTAMPTZ,                    -- mikor egyezett be az app
  is_used    BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '1 hour')
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


-- ── app_config ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL DEFAULT '',
  value_type TEXT NOT NULL DEFAULT 'string',
  description TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS app_config_updated_by_idx ON public.app_config(updated_by);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read app_config"    ON public.app_config FOR SELECT TO public USING (true);
CREATE POLICY "Admins manage app_config"  ON public.app_config FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access app_config" ON public.app_config FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE TRIGGER on_app_config_updated
  BEFORE UPDATE ON public.app_config FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- anon csak SELECT (app induláskor)
GRANT SELECT ON public.app_config TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_config TO authenticated;
GRANT ALL ON public.app_config TO service_role;

INSERT INTO public.app_config (key, value, value_type, description) VALUES
  ('maintenance_mode',           'false',  'bool',   'Ha true, az app maintenance képernyőt mutat.'),
  ('maintenance_message',        'Az alkalmazás karbantartás alatt áll. Hamarosan visszatérünk!', 'string', 'Karbantartás üzenet.'),
  ('maintenance_title',          'Karbantartás', 'string', 'Karbantartás képernyő főcíme.'),
  ('min_app_version_ios',        '1.0.0',  'string', 'Minimálisan szükséges iOS app verzió (force update).'),
  ('min_app_version_android',    '1.0.0',  'string', 'Minimálisan szükséges Android app verzió (force update).'),
  ('latest_app_version_ios',     '1.0.0',  'string', 'Legfrissebb iOS verzió.'),
  ('latest_app_version_android', '1.0.0',  'string', 'Legfrissebb Android verzió.'),
  ('app_store_url_ios',          '',       'string', 'iOS App Store link.'),
  ('app_store_url_android',      '',       'string', 'Google Play link.'),
  ('feature_registration_enabled','true',  'bool',   'Engedélyezi-e az új regisztrációt.'),
  ('feature_google_login',       'false',  'bool',   'Google OAuth bejelentkezés aktív-e.'),
  ('feature_apple_login',        'false',  'bool',   'Apple Sign In aktív-e.'),
  ('feature_push_notifications', 'false',  'bool',   'Push értesítések küldése aktív-e.'),
  ('feature_dark_mode_only',     'true',   'bool',   'Csak sötét téma engedélyezett.'),
  ('feature_bug_reporter',       'false',  'bool',   'In-app bug reporter aktív-e.'),
  ('feature_tutorial',           'true',   'bool',   'Feature Walkthrough tutorial aktív-e.'),
  ('app_name',                   'Skeleton App', 'string', 'Az alkalmazás neve.'),
  ('support_email',              'support@example.com', 'string', 'Támogatási e-mail cím.'),
  ('privacy_url',                '',       'string', 'Adatvédelmi nyilatkozat URL.'),
  ('terms_url',                  '',       'string', 'ÁSZF URL.')
ON CONFLICT (key) DO NOTHING;


-- ── user_sessions ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_sessions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_model        TEXT,
  device_brand        TEXT,
  os_name             TEXT,
  os_version          TEXT,
  app_version         TEXT,
  app_build           TEXT,
  locale              TEXT,
  ip_address          INET,
  geo_country         TEXT,
  geo_city            TEXT,
  geo_lat             NUMERIC(9,6),
  geo_lon             NUMERIC(9,6),
  is_active           BOOLEAN NOT NULL DEFAULT true,
  last_seen_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at          TIMESTAMPTZ,
  revoked_by          UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  supabase_session_id TEXT
);

CREATE INDEX IF NOT EXISTS user_sessions_user_id_idx    ON public.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS user_sessions_is_active_idx  ON public.user_sessions(is_active);
CREATE INDEX IF NOT EXISTS user_sessions_created_at_idx ON public.user_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS user_sessions_last_seen_idx  ON public.user_sessions(last_seen_at DESC);
CREATE INDEX IF NOT EXISTS user_sessions_revoked_by_idx ON public.user_sessions(revoked_by);

-- FK user_profiles-ra is (PostgREST embedding)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_sessions_user_id_fk') THEN
    ALTER TABLE public.user_sessions
      ADD CONSTRAINT user_sessions_user_id_fk
      FOREIGN KEY (user_id) REFERENCES public.user_profiles(id) ON DELETE CASCADE;
  END IF;
END $$;

ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own sessions"      ON public.user_sessions FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Admins can read all sessions"     ON public.user_sessions FOR SELECT TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins can update sessions"       ON public.user_sessions FOR UPDATE TO authenticated USING (public.is_admin(auth.uid()));
CREATE POLICY "Users can revoke own sessions"    ON public.user_sessions FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Service role full access sessions" ON public.user_sessions FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_sessions TO authenticated;
GRANT ALL ON public.user_sessions TO service_role;


-- ── backup_logs ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.backup_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  backup_type   TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'running',
  duration_secs INTEGER,
  size_bytes    BIGINT,
  s3_path       TEXT,
  error_message TEXT,
  triggered_by  TEXT NOT NULL DEFAULT 'cron',
  metadata      JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS backup_logs_created_at_idx ON public.backup_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS backup_logs_status_idx     ON public.backup_logs(status);
CREATE INDEX IF NOT EXISTS backup_logs_type_idx       ON public.backup_logs(backup_type);

ALTER TABLE public.backup_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage backup_logs" ON public.backup_logs FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access backup_logs" ON public.backup_logs FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.backup_logs TO authenticated;
GRANT ALL ON public.backup_logs TO service_role;


-- ── resource_snapshots ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.resource_snapshots (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recorded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  cpu_percent  NUMERIC(5,2),
  ram_used_mb  INTEGER,
  ram_total_mb INTEGER,
  disk_used_gb NUMERIC(8,2),
  disk_total_gb NUMERIC(8,2),
  disk_percent NUMERIC(5,2)
);

CREATE INDEX IF NOT EXISTS resource_snapshots_recorded_at_idx ON public.resource_snapshots(recorded_at DESC);

ALTER TABLE public.resource_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read resource_snapshots" ON public.resource_snapshots FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));
CREATE POLICY "Service role full access resource_snapshots" ON public.resource_snapshots FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.resource_snapshots TO authenticated;
GRANT ALL ON public.resource_snapshots TO service_role;


-- ── bug_reports ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bug_reports (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  reporter_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title          TEXT NOT NULL,
  description    TEXT,
  priority       TEXT NOT NULL DEFAULT 'medium'
                   CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  route_name     TEXT,
  device_info    JSONB DEFAULT '{}'::jsonb,
  logs           JSONB DEFAULT '[]'::jsonb,
  screenshot_url TEXT,
  status         TEXT NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open', 'in_progress', 'resolved', 'wont_fix')),
  assigned_to    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at    TIMESTAMPTZ,
  admin_notes    TEXT
);

CREATE INDEX IF NOT EXISTS bug_reports_created_at_idx  ON public.bug_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS bug_reports_priority_idx    ON public.bug_reports(priority);
CREATE INDEX IF NOT EXISTS bug_reports_status_idx      ON public.bug_reports(status);
CREATE INDEX IF NOT EXISTS bug_reports_reporter_id_idx ON public.bug_reports(reporter_id);
CREATE INDEX IF NOT EXISTS bug_reports_assigned_to_idx ON public.bug_reports(assigned_to);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins full access bug_reports" ON public.bug_reports FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
CREATE POLICY "Reporters can read own bug_reports" ON public.bug_reports FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());
CREATE POLICY "Service role full access bug_reports" ON public.bug_reports FOR ALL TO service_role
  USING (true) WITH CHECK (true);
CREATE POLICY "Anon can insert bug_reports" ON public.bug_reports FOR INSERT TO anon
  WITH CHECK (true);

GRANT INSERT ON public.bug_reports TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bug_reports TO authenticated;
GRANT ALL ON public.bug_reports TO service_role;


-- ── translations ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.translations (
  key     TEXT PRIMARY KEY,
  hu      TEXT NOT NULL DEFAULT '',
  en      TEXT NOT NULL DEFAULT '',
  locales JSONB NOT NULL DEFAULT '{}'
);

ALTER TABLE public.translations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read translations"  ON public.translations FOR SELECT USING (true);
CREATE POLICY "Admins manage translations" ON public.translations FOR ALL USING (public.is_admin(auth.uid()));

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

-- Egyszerre csak egy aktív verzió per dokumentum típus
CREATE UNIQUE INDEX IF NOT EXISTS idx_legal_documents_active_id
  ON public.legal_documents (id) WHERE (is_active = true);

ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read legal_documents"   ON public.legal_documents FOR SELECT TO public USING (true);
CREATE POLICY "Admins manage legal_documents" ON public.legal_documents FOR ALL TO authenticated
  USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));

GRANT SELECT ON public.legal_documents TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.legal_documents TO authenticated;
GRANT ALL ON public.legal_documents TO service_role;

-- Alapértelmezett jogi dokumentumok
INSERT INTO public.legal_documents (id, version, is_active, title_locales, content_locales) VALUES
  ('terms', '1.0', true,
    '{"hu": "Általános Szerződési Feltételek", "en": "Terms of Service", "de": "Allgemeine Geschäftsbedingungen"}',
    '{"hu": "<b>ÁSZF</b><br/>A szolgáltatás használatával Ön elfogadja a jelen feltételeket.", "en": "<b>Terms of Service</b><br/>By using our service, you agree to these terms.", "de": "<b>AGB</b><br/>Durch die Nutzung stimmen Sie diesen Bedingungen zu."}'
  ),
  ('privacy', '1.0', true,
    '{"hu": "Adatvédelmi Nyilatkozat", "en": "Privacy Policy", "de": "Datenschutzerklärung"}',
    '{"hu": "<b>Adatvédelem</b><br/>Az Ön adatainak védelme kiemelten fontos számunkra.", "en": "<b>Privacy Policy</b><br/>Your privacy is of utmost importance to us.", "de": "<b>Datenschutz</b><br/>Der Schutz Ihrer Daten ist uns sehr wichtig."}'
  )
ON CONFLICT (id, version) DO NOTHING;


-- ── audit_log ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.audit_log (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  action       TEXT NOT NULL,
  actor_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email  TEXT,
  actor_role   TEXT,
  target_table TEXT,
  details      JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS audit_log_created_at_idx ON public.audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS audit_log_action_idx     ON public.audit_log(action);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read audit_log" ON public.audit_log FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

-- Csak service_role írhat
GRANT SELECT ON public.audit_log TO authenticated;
GRANT ALL ON public.audit_log TO service_role;


-- ════════════════════════════════════════════════════════════
-- 3. GLOBÁLIS GRANTS (sequences, routines)
-- ════════════════════════════════════════════════════════════

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL   ON ALL SEQUENCES IN SCHEMA public TO service_role;
REVOKE ALL  ON ALL SEQUENCES IN SCHEMA public FROM anon;

REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM anon;

-- Function grants
REVOKE ALL ON FUNCTION public.get_admin_cost_stats()              FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_cost_stats()           TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_app_config_map()             TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.validate_invitation_token(UUID)  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_first_setup()                 TO anon, authenticated, service_role;


-- ════════════════════════════════════════════════════════════
-- 4. REALTIME PUBLICATION
-- ════════════════════════════════════════════════════════════

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END$$;

-- Csak az admin UI által ténylegesen subscribed táblák
ALTER PUBLICATION supabase_realtime SET TABLE
  public.security_logs,
  public.items;
