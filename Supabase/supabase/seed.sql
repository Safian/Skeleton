-- ============================================================
-- Seed: demo adatok (csak local dev-hez!)
-- ============================================================

-- Demo items (user_id-t auth.uid() helyett manuálisan kell beállítani
-- vagy a Flutter appból regisztrálás után futtatni)

-- Példa: admin user role-nak beállítása (UUID cseréld le!)
-- UPDATE public.user_profiles SET role = 'admin' WHERE email = 'admin@example.com';

-- Demo items (ha ismert a user_id):
-- INSERT INTO public.items (user_id, title, description, category, is_active) VALUES
--   ('USER_UUID', 'Első elem', 'Ez a demo első eleme.', 'Demo', true),
--   ('USER_UUID', 'Második elem', 'Ez a demo második eleme.', 'Demo', true),
--   ('USER_UUID', 'Inaktív elem', 'Ez az elem inaktív.', 'Demo', false);
