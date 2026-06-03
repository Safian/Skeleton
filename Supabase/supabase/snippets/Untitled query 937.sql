-- ============================================================
-- Migration 003: Admin Features
-- app_settings, ai_models, gpt_usage_logs, app_error_logs,
-- user_push_tokens, push_notification_logs, cost stats RPC
-- ============================================================

-- ── app_settings ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_settings (
  id          TEXT PRIMARY KEY,
  value       TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT ''
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage app_settings" ON public.app_settings
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

INSERT INTO public.app_settings (id, value, description) VALUES
  ('daily_api_cost_limit', '5.0', 'Globális napi API költségkorlát USD-ben.'),
  ('firebase_service_account_json', '', 'Google Firebase Service Account JSON a push értesítésekhez.'),
  ('firebase_vapid_key', '', 'Web Push VAPID kulcs.')
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

CREATE POLICY "Admins manage ai_models" ON public.ai_models
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access ai_models" ON public.ai_models
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Trigger: only one model can be default at a time
CREATE OR REPLACE FUNCTION public.handle_ai_model_single_default()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE public.ai_models SET is_default = false WHERE id != NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_single_ai_model_default ON public.ai_models;
CREATE TRIGGER trg_single_ai_model_default
  AFTER INSERT OR UPDATE ON public.ai_models
  FOR EACH ROW EXECUTE FUNCTION public.handle_ai_model_single_default();

-- Default seed model
INSERT INTO public.ai_models (name, model, is_default, system_prompt)
VALUES ('GPT-4o Mini', 'gpt-4o-mini', true, null)
ON CONFLICT DO NOTHING;

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

ALTER TABLE public.gpt_usage_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read gpt_usage_logs" ON public.gpt_usage_logs
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access gpt_logs" ON public.gpt_usage_logs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_gpt_usage_logs_created_at ON public.gpt_usage_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gpt_usage_logs_user_id    ON public.gpt_usage_logs(user_id);

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

ALTER TABLE public.app_error_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read app_error_logs" ON public.app_error_logs
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

CREATE POLICY "Authenticated users insert own logs" ON public.app_error_logs
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "Service role full access error_logs" ON public.app_error_logs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_app_error_logs_created_at ON public.app_error_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_error_logs_app        ON public.app_error_logs(app);
CREATE INDEX IF NOT EXISTS idx_app_error_logs_error_type ON public.app_error_logs(error_type);

-- ── user_push_tokens ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_push_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE NOT NULL,
  token      TEXT NOT NULL,
  platform   TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  CONSTRAINT unique_user_token UNIQUE (user_id, token)
);

ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own push tokens" ON public.user_push_tokens
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins read all push tokens" ON public.user_push_tokens
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access push_tokens" ON public.user_push_tokens
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── push_notification_logs ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.push_notification_logs (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
  sender_id      UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  target_group   TEXT NOT NULL,
  target_user_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,
  status         TEXT NOT NULL,
  error_message  TEXT,
  tokens_count   INTEGER DEFAULT 0 NOT NULL
);

ALTER TABLE public.push_notification_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage push_notification_logs" ON public.push_notification_logs
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access push_logs" ON public.push_notification_logs
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ── get_admin_cost_stats RPC ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_cost_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_today_start  TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'UTC');
  v_month_start  TIMESTAMPTZ := date_trunc('month', NOW() AT TIME ZONE 'UTC');
  v_gpt_today    NUMERIC := 0;
  v_gpt_month    NUMERIC := 0;
  v_in_tokens    BIGINT  := 0;
  v_out_tokens   BIGINT  := 0;
BEGIN
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

REVOKE ALL ON FUNCTION public.get_admin_cost_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_cost_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_cost_stats() TO service_role;

-- ── Grants ────────────────────────────────────────────────────
GRANT ALL ON public.app_settings          TO anon, authenticated, service_role;
GRANT ALL ON public.ai_models             TO anon, authenticated, service_role;
GRANT ALL ON public.gpt_usage_logs        TO anon, authenticated, service_role;
GRANT ALL ON public.app_error_logs        TO anon, authenticated, service_role;
GRANT ALL ON public.user_push_tokens      TO anon, authenticated, service_role;
GRANT ALL ON public.push_notification_logs TO anon, authenticated, service_role;
