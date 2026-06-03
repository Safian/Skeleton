-- ============================================================
-- 02_seed.sql – Demo adatok lokális fejlesztéshez
-- Csak dev környezetben fut!
-- ============================================================

-- Admin user létrehozása (belépés után állítsd be):
-- UPDATE public.user_profiles SET role = 'admin'
-- WHERE email = 'admin@skeleton.local';

-- Demo items (a user_id-t az első regisztrált userrel töltsd ki)
-- INSERT INTO public.items (user_id, title, description, category, is_active) VALUES
--   ('USER-UUID-HERE', 'Demo elem 1', 'Az első demo elem leírása.', 'Demo', true),
--   ('USER-UUID-HERE', 'Demo elem 2', 'A második demo elem leírása.', 'Demo', true),
--   ('USER-UUID-HERE', 'Inaktív elem', 'Ez az elem inaktív.', 'Demo', false);

SELECT 'Skeleton lokális adatbázis kész! 🚀' AS status;
