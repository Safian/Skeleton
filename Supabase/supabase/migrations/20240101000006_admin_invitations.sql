-- ============================================================
-- Migration 006: Admin Invitation System
-- Adminok meghívhatnak más adminokat egyedi tokennel.
-- ============================================================

-- ── admin_invitations ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_invitations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token         UUID NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  email         TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'admin',
  invited_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '48 hours'),
  accepted_at   TIMESTAMPTZ,
  is_used       BOOLEAN NOT NULL DEFAULT false,
  note          TEXT         -- opcionális megjegyzés az adminnak
);

CREATE INDEX IF NOT EXISTS admin_invitations_token_idx     ON public.admin_invitations(token);
CREATE INDEX IF NOT EXISTS admin_invitations_email_idx     ON public.admin_invitations(email);
CREATE INDEX IF NOT EXISTS admin_invitations_is_used_idx   ON public.admin_invitations(is_used);
CREATE INDEX IF NOT EXISTS admin_invitations_expires_at_idx ON public.admin_invitations(expires_at);

ALTER TABLE public.admin_invitations ENABLE ROW LEVEL SECURITY;

-- Csak adminok kezelhetik a meghívókat
CREATE POLICY "Admins manage admin_invitations"
  ON public.admin_invitations FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()))
  WITH CHECK (public.is_admin(auth.uid()));

-- Service role (edge function) full access
CREATE POLICY "Service role full access admin_invitations"
  ON public.admin_invitations FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- ── RPC: validate_invitation_token ────────────────────────────
-- Publikusan hívható; visszaadja a meghívó adatait ha érvényes.
CREATE OR REPLACE FUNCTION public.validate_invitation_token(p_token UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv RECORD;
BEGIN
  SELECT * INTO v_inv
  FROM public.admin_invitations
  WHERE token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'not_found');
  END IF;

  IF v_inv.is_used THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'already_used');
  END IF;

  IF v_inv.expires_at < now() THEN
    RETURN jsonb_build_object('valid', false, 'reason', 'expired');
  END IF;

  RETURN jsonb_build_object(
    'valid',  true,
    'email',  v_inv.email,
    'role',   v_inv.role,
    'id',     v_inv.id
  );
END;
$$;

-- Mindenki hívhatja (anon is – meghívó linken keresztül)
GRANT EXECUTE ON FUNCTION public.validate_invitation_token(UUID) TO anon, authenticated, service_role;

-- ── app_settings: e-mail konfig ───────────────────────────────
INSERT INTO public.app_settings (id, value, description) VALUES
  ('smtp_from_email',  '', 'Feladó e-mail cím (pl. noreply@sajatdomain.com).'),
  ('smtp_from_name',   'Admin', 'Feladó megjelenített neve.'),
  ('app_base_url',     '', 'Az app alap URL-je a meghívó linkhez (pl. https://app.sajatdomain.com).'),
  ('resend_api_key',   '', 'Resend.com API kulcs az e-mail küldéshez.'),
  ('mailgun_api_key',  '', 'Mailgun API kulcs (alternatíva Resend helyett).'),
  ('mailgun_domain',   '', 'Mailgun domain (pl. mail.sajatdomain.com).')
ON CONFLICT (id) DO NOTHING;

-- ── Grants ────────────────────────────────────────────────────
GRANT ALL ON public.admin_invitations TO authenticated, service_role;
