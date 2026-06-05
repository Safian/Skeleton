# Skeleton – Security Review TODO

Háromirányú review (Flutter kód · Supabase config · biztonság) – minden pont lezárva.

---

## 🔴 KRITIKUS – mind lezárva

- [x] **Jogosultság-eszkaláció** – `user_profiles` UPDATE policy `role` mező korlátozás nélkül.
  *Fix:* `BEFORE UPDATE` trigger (migration 004); nem-admin nem módosíthatja saját `role`-ját.

- [x] **`GRANT ALL TO anon`** az init útvonalon (`init/01_schema.sql`).
  *Fix:* least-privilege grantok; migration 004 logikájának tükrözése.

- [x] **Első regisztráló auto-admin + nyílt signup.**
  *Fix:* `register-first-admin` – session nem kerül vissza; `SETUP_TOKEN` env-gate; TOCTOU-t a trigger DB-szinten kezeli.

- [x] **Auto-confirm email + nyílt signup.**
  *Döntés:* tudatos kompromisszum lokálisan (migration 011 komment); production előtt `enable_confirmations=true` javasolt.

---

## 🟠 HIGH – mind lezárva

- [x] **Token-prefix szivárgás logba** – `session_logger.dart` access-token részletet küldött.
  *Fix:* `session.user.id` használata.

- [x] **`isClosed` guard hiánya** post-close `emit` crash ellen.
  *Fix:* `if (!isClosed) emit(...)` minden async emit előtt.

- [x] **Fordítási hiba** – `BugReporterGestureDetector` hiányzó `repaintKey`.
  *Fix:* `GlobalKey` + `RepaintBoundary`.

- [x] **Titkok a repo `.env`-ben** – nincs `.gitignore`.
  *Fix:* gyökér `.gitignore`; `Scripts/rotate_secrets.sh`.

- [x] **`bug-report` edge function unauthenticated** – korlátlan DB-insert, Telegram spam.
  *Fix:* CORS allow-list, méret-/hosszkorlátok, opcionális JWT.

- [x] **`delete-account` csak kijelentkeztet** (GDPR).
  *Fix:* `delete-account` edge function; Flutter hívja; cascade delete.

- [x] **Hiányzó `audit_log` tábla** – `translate-language` minden hívásnál hibát dobott.
  *Fix:* `audit_log` tábla RLS-sel (migration 016).

- [x] **Realtime széles körű expozíció.**
  *Fix:* migration 018 – explicit `supabase_realtime` publikáció (`security_logs`, `items`); `user_sessions`, `gpt_usage_logs` kizárva.

---

## 🟡 MEDIUM – mind lezárva

- [x] **`GRANT ALL ON app_config TO anon`** – least-privilege sértés.
  *Fix:* `REVOKE ALL; GRANT SELECT` (migration 016).

- [x] **Mutable `search_path` SECURITY DEFINER** – `cleanup_old_resource_snapshots()`.
  *Fix:* `SET search_path = public`.

- [x] **Wildcard CORS** minden edge functionon.
  *Fix:* `ALLOWED_ORIGINS` allow-list mind a 7 érintett functionban.

- [x] **`app-config` ismeretlen kulcsok kiszivárgása.**
  *Fix:* `AppConfigResponse` struct – csak whitelistelt mezők.

- [x] **`register-first-admin` TOCTOU + teljes session visszaadva.**
  *Fix:* csak `ok: true, user_id` visszaadása; `SETUP_TOKEN` gate.

- [x] **Spoofolható kliens-IP** (`cf-connecting-ip`/`x-forwarded-for`).
  *Döntés:* elfogadható kockázat – megbízható proxy réteg felelős érte deployment során.

- [x] **`AuthCubit` DI hiánya** – mind a 3 `AuthScreen` új `AuthRepository()`-t példányosított.
  *Fix:* `ctx.read<AuthRepository>()`.

- [x] **`UsersCubit` role-update Equatable dedup** – UI beragadás hiba esetén.
  *Fix:* `emit(s.copyWith())`.

- [x] **`AdminRepository.getStats` szekvenciális fetch.**
  *Fix:* `Future.wait([users, items])`.

- [x] **Gyenge/inkonzisztens jelszó-minimum.**
  *Fix:* `minimum_password_length = 8` mindenhol (`config.toml`, `docker-compose`, `admin-invite-accept`).

- [x] **Két párhuzamos séma-forrás** (`init/01_schema.sql` vs `migrations/`).
  *Döntés:* az `init/` docker-compose lokális belépési pont, a `migrations/` Supabase CLI belépési pont – párhuzamosság szándékos; a hardening mindkét útvonalon jelen van.

- [x] **Orphan snippet** (`supabase/snippets/Untitled query 937.sql`).
  *Fix:* fájl törölve.

---

## 🟢 LOW – mind lezárva

- [x] **Hiányzó FK indexek** – `admin_invitations`, `security_logs`, `banned_ips`, `bug_reports`, `push_notification_logs`, `app_config`, `user_sessions`.
  *Fix:* migration 017.

- [x] **Hibák elnyelése logolás nélkül** – `translation_repository.dart`, `config_repository.dart`.
  *Fix:* `debugPrint` a catch blokkban; admin repo defenzív null-parse.

- [x] **Null-cast crash** – `translation_repository.dart` `item['hu'] as String`.
  *Fix:* defenzív parse + hibalog.

- [x] **`security_log.dart` non-null cast-ok** realtime sorokon.
  *Fix:* `as String?`, `DateTime.tryParse`, fallback értékek.

- [x] **Nem konstans-idejű API-kulcs összehasonlítás** (`security-alert`).
  *Fix:* `timingSafeEqual()` – XOR-akkumulátor.

- [x] **SSRF admin-vezérelt URL** (`security-unban` webhook).
  *Fix:* URL validáció (csak http/https) + `X-Unban-Secret` header.

- [x] **Open redirect** – `GOTRUE_URI_ALLOW_LIST: "*"`.
  *Fix:* explicit `http://localhost:3000,http://localhost:5000`.

- [x] **`bug_reporter.dart` halott kód** – screenshot soha nem töltődött fel; formData ág nem futott.
  *Fix:* halott `formData` ág és TODO-k eltávolítva; egységes submit path.

- [x] **VPS unban listener auth nélkül** (`Scripts/security/vps-unban-listener.sh`).
  *Fix:* `X-Unban-Secret` ellenőrzés `UNBAN_LISTENER_SECRET` env alapján; edge function küldi a headert.

- [x] **Postgres login role-ok hardcode `'postgres'` jelszóval** (`init/00_roles.sql`).
  *Döntés:* `volumes/db/roles.sql` (mounted: `99-roles.sql`) azonnal felülírja `POSTGRES_PASSWORD`-dal.

- [x] **Demo JWT kulcsok fallback default-ként** a compose fájlokban.
  *Döntés:* helyi fejlesztői szükséglet; `rotate_secrets.sh` generál éles értékeket.

---

---

## 🚧 HIÁNYZÓ FUNKCIÓK – Mérföldkő backlog

### M2.1 – FlutterSecureStorage (Client + Admin)
- [x] `flutter_secure_storage` csomag hozzáadása `client/pubspec.yaml`-ba és `admin/pubspec.yaml`-ba
- [x] `SecureStorageService` osztály létrehozása: auth token és session adatok explicit mentése iOS Keychain / Android Keystore szintre (`encryptedSharedPreferences: true`)
- [x] `AuthRepository` frissítése: login után token cache `SecureStorageService`-be, logout-kor törlés

### M2.3 – Session Metadata Logging (Client)
- [x] `device_info_plus` + `package_info_plus` csomag hozzáadása `client/pubspec.yaml`-ba
- [x] `SessionLogService` létrehozása a clientben: `DeviceInfoPlugin` + `PackageInfo` adatgyűjtés
- [x] `SessionCubit._onUserLoggedIn()` kiegészítése: sikeres login után hívja meg `/functions/v1/session-log` endpointot az eszközadatokkal

### M2.4 – Deferred Deep Linking
- [x] **Backend:** `pending-invites` Edge Function létrehozása (`POST /functions/v1/pending-invites`): fogadja a webes `/invite?token=XYZ` redirect előtt a kliens IP-jét + metaadatait, menti `pending_invites` táblába
- [x] **Backend:** `pending_invites` tábla migration (ip_address, token, metadata, created_at, matched_at)
- [x] **Backend:** `deferred-link-check` logika hozzáadása meglévő functionhoz: az app első indításán a kliens IP alapján megnézi van-e 1 órán belüli `pending_invite` egyezés, ha igen visszaadja a tokent
- [x] **Client:** `SessionCubit` / `DeepLinkService` kiegészítése: legelső indításkor IP küldése backendnek, egyezés esetén automatikus `/invite-accept` navigáció

### M3.1 – Soft/Force Update (Client)
- [x] `SessionCubit._init()` módosítása: `isInMaintenance()` DB-ping helyett hívja meg az `app-config` endpointot (`/functions/v1/app-config`) és dolgozza fel a teljes `AppConfigResponse`-t
- [x] `SessionSoftUpdate` és `SessionForceUpdate` állapotok hozzáadása `session_state.dart`-ba (current + minimum + store URL mezőkkel)
- [x] Verziószám-összehasonlító helper (`semver compare`) a `SessionCubit`-ban
- [x] `SoftUpdateScreen` és `ForceUpdateScreen` UI widgetek a clientben (store linkkel)
- [x] `AppRoot` routing kiegészítése az új állapotokra

### M4.1 – QA Shield Bug Reporter (Client UI)
- [x] `flutter_secure_storage`-tól független client-oldali log buffer (`List<String>`, max 50 bejegyzés, körkörösen felülírva)
- [x] `QaShieldOverlay` wrapper widget: csak `kDebugMode`-ban aktív, 3 ujjas 3×-os tap `GestureDetector`
- [x] Screenshot capture: `RepaintBoundary` + `GlobalKey` + `RenderRepaintBoundary.toImage()`
- [x] Annotáló vászon: `CustomPainter` alapú rajzoló felület a screenshot felett
- [x] Bug report form overlay: cím, leírás, prioritás, pre-filled route + eszközadatok + utolsó 50 log
- [x] `BugReportRepository` hozzáadása a clienthez, multipart upload a `/functions/v1/bug-report` endpointra
- [x] `QaShieldOverlay` beillesztése a client `main.dart` MaterialApp-ba

### M4.2 – Feature Walkthrough (Client)

#### Lokalizáció-alap (előfeltétel)
- [x] `flutter_localizations` + `intl` csomag hozzáadása `client/pubspec.yaml`-ba
- [x] `l10n.yaml` konfigurációs fájl létrehozása (`arb-dir: lib/l10n`, `template-arb-file: app_hu.arb`, `output-localization-file: app_localizations.dart`)
- [x] `.arb` fájlok létrehozása (`lib/l10n/app_hu.arb`, `lib/l10n/app_en.arb`) tutorial kulcsokkal (`tutorial.home.*`, `tutorial.list.*` stb.)
- [x] `MaterialApp` `localizationsDelegates` + `supportedLocales` bekötése; meglévő `TranslationCubit` mellé (nem helyette)

#### Tutorial rendszer
- [x] `showcaseview` csomag hozzáadása `client/pubspec.yaml`-ba
- [x] `TutorialService` létrehozása: `SharedPreferences`-alapú "láttam-e már" állapot egyedi `screen_id` String kulcsonként; `hasSeenTutorial(id)` + `markSeen(id)` + `resetAll()` API
- [x] `ShowCaseWidget` + `Showcase` widgetek beillesztése a főbb képernyőkre (DashboardScreen)
- [x] Automatikus első futás: képernyő `initState`-ben `TutorialService.hasSeenTutorial(screenId)` ellenőrzés → ha false, `WidgetsBinding.addPostFrameCallback` → showcase indítás → `markSeen()`
- [x] "Tutorialok újraindítása" gomb hozzáadása a `SettingsScreen`-be (`TutorialService.resetAll()`)

---

## 📌 Migráció-állapot

| Migration | Tartalom | Remote |
|-----------|----------|--------|
| 016 | role-guard trigger, audit_log, app_config grant, cleanup search_path | ✅ alkalmazva |
| 017 | FK indexek | ✅ alkalmazva |
| 018 | Explicit realtime publikáció | ⏳ `supabase db push` szükséges |
| 019 | Deferred deep link – `pending_invites` tábla | ⏳ `supabase db push` szükséges |

**Friss telepítés:** `supabase db reset` – az összes migration sorban lefut.
