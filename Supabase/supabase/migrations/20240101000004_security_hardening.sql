-- ============================================================
-- Migration 004: Security Hardening
-- Applied: 2026-06-02
--
-- Fixes two vulnerabilities:
--   1. get_admin_cost_stats() callable by any authenticated user
--      (no role check inside the SECURITY DEFINER function)
--   2. GRANT ALL TO anon/authenticated — overly broad privileges
--      that violate the principle of least privilege
-- ============================================================


-- ── FIX 1: get_admin_cost_stats() — enforce admin role ───────
-- VULNERABILITY: Function is SECURITY DEFINER + GRANT-ed to all
-- authenticated users with no role check inside. Any logged-in
-- user can call rpc('get_admin_cost_stats') and read API cost data.
-- FIX: Add admin check as the very first statement.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_admin_cost_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today_start  TIMESTAMPTZ := date_trunc('day', NOW() AT TIME ZONE 'UTC');
  v_month_start  TIMESTAMPTZ := date_trunc('month', NOW() AT TIME ZONE 'UTC');
  v_gpt_today    NUMERIC := 0;
  v_gpt_month    NUMERIC := 0;
  v_in_tokens    BIGINT  := 0;
  v_out_tokens   BIGINT  := 0;
BEGIN
  -- FIXED: reject non-admins before touching any data
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'permission denied: admin role required'
      USING ERRCODE = '42501';
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

REVOKE ALL ON FUNCTION public.get_admin_cost_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_admin_cost_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_cost_stats() TO service_role;


-- ── FIX 2: Least-privilege GRANT corrections ─────────────────
-- VULNERABILITY: Previous migrations used GRANT ALL ON ... TO anon,
-- authenticated which gives INSERT/UPDATE/DELETE/TRUNCATE to
-- unauthenticated visitors. RLS still protects the data, but if
-- any table is ever missing a policy or has RLS disabled, anon
-- users would have unrestricted write access.
--
-- FIX: Revoke ALL from anon/authenticated, then re-grant only the
-- minimum needed. service_role keeps ALL (it bypasses RLS anyway).
--
-- Tables from 01_schema.sql
-- ─────────────────────────────────────────────────────────────

-- user_profiles
REVOKE ALL ON public.user_profiles FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_profiles TO authenticated;
-- anon has no business touching user_profiles
GRANT ALL ON public.user_profiles TO service_role;

-- items
REVOKE ALL ON public.items FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.items TO authenticated;
GRANT ALL ON public.items TO service_role;

-- Tables from 003_admin_features.sql

-- app_settings (admin-only via RLS; no anon access needed)
REVOKE ALL ON public.app_settings FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;

-- ai_models (authenticated read via RLS policy; no anon access)
REVOKE ALL ON public.ai_models FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_models TO authenticated;
GRANT ALL ON public.ai_models TO service_role;

-- gpt_usage_logs (admin read + service_role write only)
REVOKE ALL ON public.gpt_usage_logs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.gpt_usage_logs TO authenticated;
GRANT ALL ON public.gpt_usage_logs TO service_role;

-- app_error_logs (authenticated can insert own; admin can read all)
REVOKE ALL ON public.app_error_logs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_error_logs TO authenticated;
GRANT ALL ON public.app_error_logs TO service_role;

-- user_push_tokens (users manage own; admin reads all)
REVOKE ALL ON public.user_push_tokens FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_tokens TO authenticated;
GRANT ALL ON public.user_push_tokens TO service_role;

-- push_notification_logs (admin-only via RLS)
REVOKE ALL ON public.push_notification_logs FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.push_notification_logs TO authenticated;
GRANT ALL ON public.push_notification_logs TO service_role;

-- Sequences (needed for INSERT with gen_random_uuid() fallback paths)
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL  ON ALL SEQUENCES IN SCHEMA public TO service_role;

-- Functions: revoke the blanket GRANT ALL ON ALL ROUTINES
-- Individual functions keep their own explicit GRANTs.
REVOKE ALL ON ALL ROUTINES IN SCHEMA public FROM anon;
-- authenticated keeps per-function grants set in earlier migrations.
