-- ============================================================
-- Migration 009: Backup Logs
-- Backup futások naplózása + resource monitoring beállítások
-- ============================================================

-- ── backup_logs ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.backup_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  backup_type   TEXT NOT NULL,                   -- 'database' | 'storage' | 'full'
  status        TEXT NOT NULL DEFAULT 'running', -- 'running' | 'success' | 'failed'
  duration_secs INTEGER,
  size_bytes    BIGINT,
  s3_path       TEXT,
  error_message TEXT,
  triggered_by  TEXT NOT NULL DEFAULT 'cron',   -- 'cron' | 'manual' | 'admin'
  metadata      JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS backup_logs_created_at_idx ON public.backup_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS backup_logs_status_idx     ON public.backup_logs(status);
CREATE INDEX IF NOT EXISTS backup_logs_type_idx       ON public.backup_logs(backup_type);

ALTER TABLE public.backup_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage backup_logs"
  ON public.backup_logs FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access backup_logs"
  ON public.backup_logs FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- ── resource_snapshots – rövid CPU/RAM/disk előzmény ──────────
CREATE TABLE IF NOT EXISTS public.resource_snapshots (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  cpu_percent NUMERIC(5,2),
  ram_used_mb INTEGER,
  ram_total_mb INTEGER,
  disk_used_gb NUMERIC(8,2),
  disk_total_gb NUMERIC(8,2),
  disk_percent NUMERIC(5,2)
);

-- Csak az utolsó 24 óra adatát tartjuk meg (auto-cleanup trigger)
CREATE INDEX IF NOT EXISTS resource_snapshots_recorded_at_idx
  ON public.resource_snapshots(recorded_at DESC);

ALTER TABLE public.resource_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins read resource_snapshots"
  ON public.resource_snapshots FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

CREATE POLICY "Service role full access resource_snapshots"
  ON public.resource_snapshots FOR ALL TO service_role
  USING (true) WITH CHECK (true);

-- Auto-cleanup: 24 óránál régebbi snapshot-ok törlése
CREATE OR REPLACE FUNCTION public.cleanup_old_resource_snapshots()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.resource_snapshots
  WHERE recorded_at < now() - interval '24 hours';
END;
$$;

-- ── app_settings: backup & monitoring konfig ──────────────────
INSERT INTO public.app_settings (id, value, description) VALUES
  ('s3_endpoint',          '', 'S3 endpoint URL (pl. https://s3.amazonaws.com vagy Hetzner Object Storage URL).'),
  ('s3_bucket',            '', 'S3 bucket neve a backupokhoz.'),
  ('s3_access_key',        '', 'S3 access key ID.'),
  ('s3_secret_key',        '', 'S3 secret access key. FONTOS: csak a VPS .env fájlban tárold!'),
  ('s3_region',            'eu-central-1', 'S3 region.'),
  ('backup_encryption_key','', 'GPG/OpenSSL titkosítási kulcs a backupokhoz (legalább 32 karakter).'),
  ('disk_alert_threshold', '85', 'Tárhely riasztás küszöb százalékban.'),
  ('ram_alert_threshold',  '90', 'RAM riasztás küszöb százalékban.')
ON CONFLICT (id) DO NOTHING;

-- ── Grants ────────────────────────────────────────────────────
GRANT ALL ON public.backup_logs         TO authenticated, service_role;
GRANT ALL ON public.resource_snapshots  TO authenticated, service_role;
