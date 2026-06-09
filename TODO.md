# Skeleton – TODO

## 📌 Migráció-állapot

| Migration | Tartalom | Remote |
|-----------|----------|--------|
| 016 | role-guard trigger, audit_log, app_config grant, cleanup search_path | ✅ alkalmazva |
| 017 | FK indexek | ✅ alkalmazva |
| 018 | Explicit realtime publikáció | ✅ alkalmazva |
| 019 | Deferred deep link – `pending_invites` tábla | ✅ alkalmazva |

**Friss telepítés:** `supabase db reset` – az összes migration sorban lefut.

---

## 🔄 KibbiAi → Skeleton portolandó fixek és átalakítások (2026-06-06)

> A KibbiAi a Skeleton sablonból indult, de azóta sok helyen javítva/átalakítva lett. Az alábbi tételek ezeket gyűjtik össze – részletes elemzés: `kibbiai_to_skeleton_findings.md`.

### 🔴 Magas prioritás – Push notification fixek  *(2026-06-06: portolva ✅)*
- [x] **FCM legacy → FCM v1 átállás**: `Supabase/supabase/functions/send-push/index.ts` átírva FCM v1-re, Service Account JSON + `npm:google-auth-library` JWT/OAuth2 alapon (`firebase_service_account_json` app_setting). A korábbi demo-mód logika megmaradt (most a Service Account hiánya váltja ki), így az admin UI kontraktusa (`{ok, sent, fcm_success, fcm_failure, demo_mode?}` + `status: 'sent'|'failed'`) változatlan.
- [x] **Halott FCM token törlés (dead token grooming)**: `send-push` összegyűjti az `UNREGISTERED`/`INVALID_ARGUMENT` hibás token id-kat (`invalidTokensToPrune[]`) és egy batch `delete().in('id', ...)` művelettel törli őket; a válasz tartalmazza a `pruned_tokens` számot.
- [x] **Android `POST_NOTIFICATIONS` engedély hiányzik**: hozzáadva `Flutter/client/android/app/src/main/AndroidManifest.xml`-hez (csak a client appban — az admin nem fogad push-t).
- [x] **iOS APNs entitlements fájl hiányzik**: létrehozva `Flutter/client/ios/Runner/Runner.entitlements` (`aps-environment: development`), bedrótozva `CODE_SIGN_ENTITLEMENTS`-ként mind a 3 build configba, és `UIBackgroundModes → remote-notification` hozzáadva az `Info.plist`-hez. Csak a client appnál (az admin nem használ `firebase_messaging`-et).
- [x] **APNs token race condition fix**: `push_notification_service.dart` `registerToken()` 10×1mp `getAPNSToken()` polling loopot futtat iOS-en a `getToken()` előtt; timeoutnál `app_error_logs`-ba logol és kilép.
- [x] **`onTokenRefresh` listener hiányzik**: hozzáadva `StreamSubscription<String>? _tokenRefreshSub`, `cancel()` + új feliratkozás minden `registerToken()`-nél (nem halmozódnak a listenerek re-loginnál), `unregisterToken()` is leiratkozik.
- [x] **Push hibák `app_error_logs`-ba**: könnyűsúlyú inline `_logError()` helper (nem a teljes KibbiAi `LogService` portolva), minden push hibapontnál ír az `app_error_logs`-ba (`app: 'client'`, `error_type`, `error_message`, `context`), fail-open módon.
- [x] **FCM hibarészlet logolása**: `firstErrorDetail` rögzíti az első FCM hibaválasz nyers szövegét, bekerül a `push_notification_logs.error_message`-be a sikeres/sikertelen/törölt token számokkal.

### 🟡 Közepes prioritás – Admin screen szervezés
- [ ] **`AdminSectionHeader` + `AdminStatCard` kiszervezése**: hozz létre egy közös `core/components/admin_section_widgets.dart`-ot (minta: `KibbiAi_Admin/lib/screens/admin/widgets/admin_section_widgets.dart`), és cseréld le vele a duplikált header/statcard kódot a `security_screen.dart`, `invitations_screen.dart`, `config_screen.dart`, `sessions_screen.dart` fájlokban.
- [ ] **MessagesScreen tab átvétele (opcionális)**: ha az üzenetküldés funkció releváns a Skeletonnak, vedd át a `KibbiAi_Admin/lib/screens/admin/messages/messages_screen.dart` mintáját (filterezhető lista + válasz dialógus).

### 🟡 Közepes prioritás – UI/UX konvenciók
- [ ] **"Lista csonkolás" szabály bevezetése**: dokumentáld az ARCHITECTURE.md / CLAUDE.md-ben a KibbiAi 15. szekciójában leírt mintát (max 4 elem inline + "Továbbiak" pill → `DraggableScrollableSheet` kereséssel, szűrő chipekkel, számláló badge-dzsel, "Nincs találat" üres állapottal), és alkalmazd minden olyan listára, ahol >4 elem lehet (pl. a meglévő `banned_ips_sheet.dart` már félig megvan – egészítsd ki kereséssel/szűrővel/üres állapottal).
- [ ] **Közös szűrő-chip widget kiszervezése**: emeld ki egy `_FilterChip`/kategória chip komponenst a `core/components/`-ba (minta: KibbiAi `_CategoryChip`).

### 🟢 Alacsony prioritás – Flutter 3.x deprecation cleanup
- [ ] **`withOpacity()` → `.withValues(alpha:)`**: 6 helyen javítandó – `security_log_tile.dart` (68, 116, 122. sor), `security_stats_row.dart` (118, 125. sor), `banned_ips_sheet.dart` (92. sor).
- [ ] **`activeColor` → `activeThumbColor`** (és `inactiveColor` → `inactiveTrackColor`): 8 helyen javítandó – `config_screen.dart` (164), `ai_screen.dart` (511), `settings_screen.dart` (270), `components_screen.dart` (266, 291, 308, 336, 337).

### 🔵 Strukturális (nagyobb döntést igényel)
- [ ] **Megosztott widget package**: fontold meg egy `Skeleton_Shared` Flutter package létrehozását (minta: `KibbiAi_Shared`), hogy a kliens és admin app ne duplikálja a `core/components/` kódját.
- [ ] **Migráció-konvenció**: az új RLS-érintő migrációkban használj `DROP POLICY IF EXISTS … CREATE POLICY` mintát az újrafuttathatóság érdekében (KibbiAi migráció 012 mintája).
- [ ] **Üres chat session törlés**: ha a Skeleton chat modulja is felhalmoz üres session-öket, vedd át a KibbiAi `_deleteSessionIfEmpty()` mintáját (`chat_cubit.dart`, `startNewSession()`/`close()` hook).
