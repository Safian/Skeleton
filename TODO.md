# Skeleton – Review TODO

Háromirányú review (Flutter kód · Supabase config · biztonság) eredménye.
Jelölés: `[x]` = megoldva, `[ ]` = nyitott, `[~]` = részben / döntést igényel.

---

## 🔴 KRITIKUS

- [x] **Jogosultság-eszkaláció: bárki admin-ná teheti magát.**
  `user_profiles` UPDATE policy `USING (auth.uid() = id)` `WITH CHECK` és oszlop-korlát nélkül → a felhasználó a saját során a `role`-t is `'admin'`-ra írhatja.
  *Fix:* `BEFORE UPDATE` trigger, ami nem-admin számára tiltja a `role` módosítását (migráció 004).

- [x] **`init/01_schema.sql`: `GRANT ALL ... TO anon`** minden public táblán (INSERT/UPDATE/DELETE) – ezt a `docker-compose.local.yml` tölti be, és nincs benne a 004 hardening megfelelője.
  *Fix:* least-privilege grantok (anon csak SELECT ahol kell), a 004 logikájának tükrözése az init útvonalon.

- [~] **Első regisztráló automatikusan admin + nyílt signup.**
  Üres `user_profiles` esetén (friss deploy / törlés után) a következő self-signup admin lesz; `register-first-admin` endpoint nem atomi és nincs gate-elve.
  *Teendő (döntés):* bootstrap csak kontrollált úton (setup-token / service_role), endpoint letiltása bootstrap után, atomi „first user" döntés.

- [~] **Auto-confirm email trigger + nyílt signup.**
  Minden új user azonnal megerősített → bárki regisztrálhat nem birtokolt email címmel. (Tudatos döntés volt; lásd 011 migráció kommentje.)
  *Teendő (döntés):* productionben `enable_confirmations=true` self-signup esetén, vagy a client signup zárása + csak meghívó.

---

## 🟠 HIGH

- [x] **Token-prefix szivárgás logba.** `Flutter/lib/services/session_logger.dart:46` az access token első 16 karakterét küldi a backendnek.
  *Fix:* `session.user.id` használata token-darab helyett.

- [x] **`isClosed` guard hiánya `emit` előtt** (post-close `emit` crash): `Flutter/lib/blocs/session/session_cubit.dart`, `admin/.../session_cubit.dart`, `admin/.../security/security_cubit.dart`.
  *Fix:* `if (!isClosed) emit(...)` minden await utáni emitnél.

- [x] **Fordítási hiba:** `Flutter/lib/main.dart:111` `BugReporterGestureDetector` a kötelező `repaintKey` nélkül példányosul → nem fordul.
  *Fix:* `GlobalKey` + `RepaintBoundary`, vagy a paraméter opcionálissá tétele.

- [x] **Valódi titkok a repo `.env`-ben, nincs `.gitignore`.** OpenAI kulcs, `service_role`, `JWT_SECRET`, Postgres jelszó.
  *Fix:* gyökér `.gitignore` (`.env`, `**/.env`); titkok rotálása (lásd `Scripts/rotate_secrets.sh`).

- [~] **`bug-report` edge function unauthenticated.** Anonim DB-insert, publikus bucket feltöltés, Telegram spam, rate-limit nélkül.
  *Teendő:* JWT vagy megosztott titok megkövetelése, rate-limit, méret/típus korlát, privát bucket + signed URL.

- [~] **`delete-account` csak kijelentkeztet** (`Flutter/lib/screens/home/settings/edit_profile_screen.dart:122`), pedig a UI végleges törlést ígér (GDPR).
  *Teendő:* `delete-account` edge function meghívása, vagy a gomb letiltása amíg nincs kész.

- [x] **Hiányzó `audit_log` tábla.** `translate-language/index.ts:193` nem létező `public.audit_log`-ba ír → minden futásnál hiba.
  *Fix:* `audit_log` tábla létrehozása RLS-sel (új migráció).

- [~] **Realtime széles körű expozíció.** `config.toml realtime.enabled` + kong anon route; ügyelni kell, mely táblák vannak a publikációban.
  *Teendő:* explicit realtime publikáció; érzékeny táblák (`security_logs`, `user_sessions`, `gpt_usage_logs`) soha ne legyenek publikálva.

---

## 🟡 MEDIUM

- [x] **`GRANT ALL ON public.app_config TO anon`** (007 a 004 után fut, így megmarad). RLS blokkol, de sérti a least-privilege elvet.
  *Fix:* `REVOKE ALL ... FROM anon; GRANT SELECT ... TO anon`.

- [x] **Mutable `search_path` SECURITY DEFINER függvény:** `cleanup_old_resource_snapshots()` (009) nincs `SET search_path`.
  *Fix:* `SET search_path = public`.

- [~] **Wildcard CORS auth-os edge function-okön** (`security-alert`, `security-unban`, `admin-invite`, `admin-invite-accept`, `app-config`, `bug-report`, `session-log`).
  *Teendő:* allow-list, mint a `translate-language`-ben.

- [~] **`app-config` minden ismeretlen kulcsot kiszór anonnak** (latens leak, ha valaha titkot tesznek `app_config`-ba).
  *Teendő:* whitelist a visszaadott kulcsokra.

- [~] **`register-first-admin` TOCTOU + teljes session visszaadása, rate-limit nélkül.**
  *Teendő:* atomi bootstrap (advisory lock / unique), endpoint gate.

- [~] **Spoofolható kliens-IP** (`session-log`, `cf-connecting-ip`/`x-forwarded-for` megbízva).
  *Teendő:* IP csak a megbízható proxy rétegből.

- [~] **`AuthCubit` nem használja a DI repository-t** (admin + client `auth_screen.dart`); új `AuthRepository()`-t példányosít.
  *Teendő:* `context.read<AuthRepository>()`.

- [~] **`UsersCubit` role-update hiba** (`admin/.../users_cubit.dart:50`): hibára ugyanazt az Equatable példányt emittálja → BLoC dedup eldobhatja, UI beragad.
  *Teendő:* friss példány / reload.

- [~] **`AdminRepository.getStats` szekvenciális, bár „párhuzamos" a komment** (`admin_repository.dart:24`).
  *Teendő:* `Future.wait`.

- [~] **Gyenge jelszó-minimum (6), inkonzisztens** (signup 6, invite 8; `config.toml:62`).
  *Teendő:* egységes ≥8 (ideálisan 12).

- [~] **Két párhuzamos séma-forrás** (`init/01_schema.sql` vs `migrations/*`) eltér (`language` oszlop, hardening).
  *Teendő:* egyetlen forrásra konszolidálni.

- [~] **`get_admin_cost_stats` sérülékeny eredeti definíció + orphan snippet** (`supabase/snippets/Untitled query 937.sql`).
  *Teendő:* a snippet fájl törlése.

---

## 🟢 LOW

- [~] **Hiányzó FK indexek:** `admin_invitations.invited_by`, `security_logs.resolved_by`, `banned_ips.log_id`, `bug_reports.assigned_to`, `push_notification_logs.sender_id/target_user_id`, `app_config.updated_by`, `user_sessions.revoked_by`.
- [~] **Hibák elnyelése logolás nélkül:** `translation_repository.dart`, `config_repository.dart` (üres dict / defaults csendben).
- [x] **Null-cast crash kockázat:** `Flutter/lib/repositories/translation_repository.dart:15` (`item['hu'] as String`) – egy null sor az egész szótárat kiüríti. (defenzív parse + hibalog hozzáadva)
- [~] **`security_log.dart:60` non-null cast-ok** realtime sorokon → malformed sor crash-eli a listenert.
- [~] **Nem konstans-idejű API-kulcs összehasonlítás** (`security-alert/index.ts:137`).
- [~] **SSRF admin-vezérelt URL-en** (`security-unban` webhook).
- [~] **Open redirect:** `GOTRUE_URI_ALLOW_LIST: "*"` mindkét compose-ban.
- [~] **`bug_reporter.dart` screenshot/annotáció halott kód** – sosem töltődik fel.
- [~] **VPS unban listener auth nélkül** (`Scripts/security/vps-unban-listener.sh`).
- [~] **Postgres login role-ok hardcode `'postgres'` jelszóval** (`init/00_roles.sql`).
- [~] **Demo JWT kulcsok fallback default-ként** a compose fájlokban (`:-super-secret...`).

---

## ⚙️ Egyéb (e session-ben elvégezve)

- [x] Migráció-konszolidáció: `user_sessions→user_profiles` FK a 008-ba, email auto-confirm a 011-be; külön 014/015 törölve.
- [x] `Scripts/rotate_secrets.sh` – POSTGRES_PASSWORD / JWT_SECRET / REALTIME_SECRET generálása (idempotens, csak default/üres értékre).
- [x] Admin login + maintenance offline lokalizáció (`context.t()` + `codebaseTranslations`); AI nyelv-generálás a pre-login kulcsokra is.

---

## 📌 A fixek alkalmazása

A DB-szintű javítások a **`20240101000016_security_review_fixes.sql`** migrációban vannak
(role-guard trigger, audit_log, app_config grant, cleanup search_path). Validálva
`BEGIN/ROLLBACK`-kel a local DB-n.

- **Remote-ra:** ✅ ALKALMAZVA (`supabase db push`, 2026-06-03). A history-ban a régi
  014/015 `reverted`-re állítva (a fizikai FK/auto-confirm a DB-ben marad), a 016 lefutott
  → a kritikus C1 role-guard, audit_log, app_config grant és cleanup fix él a remote-on.
- **Friss telepítés:** `supabase db reset` – a 008/011 már tartalmazza az FK-t és az
  auto-confirmot, a 016 a security fixeket.
- **`init/01_schema.sql`** (docker-compose.local útvonal) GRANT-jai külön javítva.
- **Flutter:** minden módosított fájl `flutter analyze` tiszta.
