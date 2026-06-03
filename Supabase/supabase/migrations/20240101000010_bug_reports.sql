-- ============================================================
-- Migration 010: Bug Reports – QA Shield [M7]
-- ============================================================

-- ── bug_reports ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bug_reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Bejelentő (opcionális, lehet anonim tesztelő)
  reporter_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Tartalmi mezők
  title           TEXT NOT NULL,
  description     TEXT,
  priority        TEXT NOT NULL DEFAULT 'medium'  -- 'low' | 'medium' | 'high' | 'critical'
                    CHECK (priority IN ('low', 'medium', 'high', 'critical')),

  -- Képernyő / navigáció
  route_name      TEXT,   -- aktuális Flutter route neve

  -- Eszközadatok (JSON)
  device_info     JSONB DEFAULT '{}'::jsonb,
  -- {
  --   "app_version": "1.2.3",
  --   "app_build":   "42",
  --   "os_name":     "iOS",
  --   "os_version":  "17.4",
  --   "device_model":"iPhone 15 Pro",
  --   "locale":      "hu_HU"
  -- }

  -- Utolsó 50 log bejegyzés
  logs            JSONB DEFAULT '[]'::jsonb,

  -- Annotált screenshot URL (Supabase Storage)
  screenshot_url  TEXT,

  -- Feldolgozás
  status          TEXT NOT NULL DEFAULT 'open'
                    CHECK (status IN ('open', 'in_progress', 'resolved', 'wont_fix')),
  assigned_to     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolved_at     TIMESTAMPTZ,
  admin_notes     TEXT
);

-- Indexek
CREATE INDEX IF NOT EXISTS bug_reports_created_at_idx  ON public.bug_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS bug_reports_priority_idx    ON public.bug_reports(priority);
CREATE INDEX IF NOT EXISTS bug_reports_status_idx      ON public.bug_reports(status);
CREATE INDEX IF NOT EXISTS bug_reports_reporter_id_idx ON public.bug_reports(reporter_id);

-- ── RLS ───────────────────────────────────────────────────────
ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

-- Adminok mindent látnak és kezelnek
CREATE POLICY "Admins full access bug_reports"
  ON public.bug_reports FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Bejelentők látják a saját reportjaikat
CREATE POLICY "Reporters can read own bug_reports"
  ON public.bug_reports FOR SELECT
  TO authenticated
  USING (reporter_id = auth.uid());

-- Service role teljes hozzáférés (edge function mentéshez)
CREATE POLICY "Service role full access bug_reports"
  ON public.bug_reports FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- Anonim felhasználók is beküldhetnek (debug/staging)
CREATE POLICY "Anon can insert bug_reports"
  ON public.bug_reports FOR INSERT
  TO anon
  WITH CHECK (true);

-- ── bug_report_screenshots Storage bucket ─────────────────────
-- A screenshot feltöltések ide kerülnek (Supabase Storage-ban manuálisan kell létrehozni)
-- Bucket neve: 'bug-screenshots' (private)
-- Path pattern: {bug_report_id}/{timestamp}.png

-- ── RPC: update_bug_status ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_bug_status(
  p_bug_id    UUID,
  p_status    TEXT,
  p_notes     TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_status NOT IN ('open', 'in_progress', 'resolved', 'wont_fix') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  UPDATE public.bug_reports
  SET
    status      = p_status,
    admin_notes = COALESCE(p_notes, admin_notes),
    resolved_at = CASE WHEN p_status IN ('resolved', 'wont_fix') THEN now() ELSE resolved_at END,
    assigned_to = CASE WHEN p_status = 'in_progress' THEN auth.uid() ELSE assigned_to END
  WHERE id = p_bug_id;
END;
$$;
