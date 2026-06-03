-- ============================================================
-- Migration 005: Security Logs & Intrusion Detection System
-- ============================================================

-- ── security_logs ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.security_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  timestamp     TIMESTAMPTZ NOT NULL DEFAULT now(),
  source        TEXT NOT NULL,                          -- 'fail2ban' | 'ssh_monitor' | 'auth_service' | stb.
  event_type    TEXT NOT NULL,                          -- 'brute_force' | 'successful_ssh_login' | 'rate_limit_exceeded' | stb.
  ip_address    INET,
  description   TEXT,
  is_resolved   BOOLEAN NOT NULL DEFAULT false,
  resolved_at   TIMESTAMPTZ,
  resolved_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  metadata      JSONB DEFAULT '{}'::jsonb               -- extra mezők tárolása
);

-- Indexek
CREATE INDEX IF NOT EXISTS security_logs_created_at_idx  ON public.security_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS security_logs_ip_address_idx  ON public.security_logs(ip_address);
CREATE INDEX IF NOT EXISTS security_logs_event_type_idx  ON public.security_logs(event_type);
CREATE INDEX IF NOT EXISTS security_logs_source_idx      ON public.security_logs(source);
CREATE INDEX IF NOT EXISTS security_logs_is_resolved_idx ON public.security_logs(is_resolved);

-- RLS
ALTER TABLE public.security_logs ENABLE ROW LEVEL SECURITY;

-- Csak adminok olvashatják
CREATE POLICY "Admins can read security_logs"
  ON public.security_logs FOR SELECT
  TO authenticated
  USING (public.is_admin(auth.uid()));

-- Csak adminok tudnak frissíteni (resolve)
CREATE POLICY "Admins can update security_logs"
  ON public.security_logs FOR UPDATE
  TO authenticated
  USING (public.is_admin(auth.uid()));

-- Service role (edge function) írhat
CREATE POLICY "Service role full access security_logs"
  ON public.security_logs FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ── security_api_keys ─────────────────────────────────────────
-- Tárolja a webhook endpointhoz használt API kulcsokat
CREATE TABLE IF NOT EXISTS public.security_api_keys (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  key_hash    TEXT NOT NULL UNIQUE,   -- bcrypt hash of the key
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_used   TIMESTAMPTZ
);

ALTER TABLE public.security_api_keys ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage security_api_keys"
  ON public.security_api_keys FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access security_api_keys"
  ON public.security_api_keys FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- ── banned_ips (aktív tiltások nyilvántartása) ─────────────────
CREATE TABLE IF NOT EXISTS public.banned_ips (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address  INET NOT NULL UNIQUE,
  reason      TEXT,
  jail        TEXT,                   -- fail2ban jail neve (pl. 'sshd')
  banned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  unbanned_at TIMESTAMPTZ,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  log_id      UUID REFERENCES public.security_logs(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS banned_ips_ip_address_idx ON public.banned_ips(ip_address);
CREATE INDEX IF NOT EXISTS banned_ips_is_active_idx  ON public.banned_ips(is_active);

ALTER TABLE public.banned_ips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage banned_ips"
  ON public.banned_ips FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access banned_ips"
  ON public.banned_ips FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- ── RPC: resolve_security_log ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_security_log(log_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Csak admin tudja meghívni
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  UPDATE public.security_logs
  SET
    is_resolved = true,
    resolved_at = now(),
    resolved_by = auth.uid()
  WHERE id = log_id;
END;
$$;

-- ── RPC: get_security_stats ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_security_stats()
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
    'total_events',         COUNT(*),
    'unresolved_events',    COUNT(*) FILTER (WHERE NOT is_resolved),
    'events_today',         COUNT(*) FILTER (WHERE created_at >= now() - interval '24 hours'),
    'brute_force_count',    COUNT(*) FILTER (WHERE event_type = 'brute_force' AND NOT is_resolved),
    'ssh_login_count',      COUNT(*) FILTER (WHERE event_type = 'successful_ssh_login' AND created_at >= now() - interval '24 hours'),
    'active_bans',          (SELECT COUNT(*) FROM public.banned_ips WHERE is_active = true),
    'top_attacker_ip',      (
                              SELECT ip_address::text FROM public.security_logs
                              WHERE event_type = 'brute_force'
                                AND created_at >= now() - interval '7 days'
                              GROUP BY ip_address
                              ORDER BY COUNT(*) DESC
                              LIMIT 1
                            )
  )
  INTO result
  FROM public.security_logs;

  RETURN result;
END;
$$;

-- ── app_settings: notification config ─────────────────────────
INSERT INTO public.app_settings (id, value, description) VALUES
  ('security_webhook_api_key', '', 'Az /api/v1/security/alert endpoint Bearer API kulcsa.'),
  ('telegram_bot_token',       '', 'Telegram Bot API token a riasztásokhoz.'),
  ('telegram_chat_id',         '', 'Telegram Chat ID ahova a riasztások mennek.'),
  ('discord_webhook_url',      '', 'Discord Webhook URL (alternatíva Telegram helyett).'),
  ('unban_webhook_url',        '', 'A szerveren futó unban endpoint URL-je (pl. http://VPS_IP:9090/unban).')
ON CONFLICT (id) DO NOTHING;
