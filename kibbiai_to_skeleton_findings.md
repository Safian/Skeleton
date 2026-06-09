# KibbiAi → Skeleton: portolandó fixek és átalakítások

> Készült: 2026-06-06. A KibbiAi a Skeleton sablonból indult, de azóta sok helyen javítva/átalakítva lett.
> Ez a dokumentum összegyűjti azokat a konkrét fixeket és refaktorokat, amelyek visszaportolhatók a Skeleton projektbe.
> A teendők rövid checklist-formában a `TODO.md` "KibbiAi → Skeleton portolandó fixek" szekciójában vannak.

---

## 1. Admin screen szervezés

**KibbiAi (`KibbiAi_Admin/lib/screens/admin/`):**
- `admin_dashboard_screen.dart` (~250 sor) — vékony shell: drawer, tab-váltó, hiba/loading állapotok
- `tabs/` — 12 fájl, tabonként egy (overview, users, ai_profiles, ai_models, image_ai, voice_ai, translations, documents, subscriptions, push, logs, deep_links)
- `security/security_screen.dart` (661 sor), `invitations/invitations_screen.dart` (248 sor), `config/config_screen.dart` (202 sor), `sessions/sessions_screen.dart` (189 sor), `messages/messages_screen.dart` (516 sor)
- `widgets/admin_section_widgets.dart` (208 sor) — közös `AdminSectionHeader` és `AdminStatCard`, mindegyik ported screen újrahasznosítja

**Skeleton (`Flutter/admin/lib/screens/home/`):**
- `home_screen.dart` (274 sor) — hasonló vékony shell, tehát a tab→subscreen szervezés alapmintája már megvan
- `security_screen.dart` (435), `invitations_screen.dart` (396), `config_screen.dart` (492), `sessions_screen.dart` (429) — hosszabbak, mert minden header/statcard kódot saját maguk duplikálnak
- **Nincs** `admin_section_widgets.dart` megfelelő — minden screen saját header/statcard stílust ír
- **Nincs** Messages tab

**Teendő:** lásd TODO checklist — `AdminSectionHeader`/`AdminStatCard` kiszervezése, opcionálisan MessagesScreen átvétele.

---

## 2. Push notification fixek

| # | Terület | Skeleton állapota | KibbiAi fix | Fájl/hivatkozás |
|---|---------|-------------------|-------------|-----------------|
| A | FCM API verzió | Legacy `fcm.googleapis.com/fcm/send` + `FCM_SERVER_KEY` (a legacy API 2024 június óta leállítva!) | FCM v1 (`/v1/projects/{id}/messages:send`) Service Account JSON + OAuth2 (`npm:jose`) | Skeleton: `Supabase/supabase/functions/send-push/index.ts:122` · KibbiAi minta: `outputs/edge-functions/send-push-notification/index.ts:211` |
| B | Halott token kezelés | Hiba esetén csak logol, nem törli a tokent | `UNREGISTERED`/`INVALID_ARGUMENT` esetén batch törlés (`invalidTokensToPrune[]`) | KibbiAi: `send-push-notification/index.ts:214, 269, 287-293, 324` |
| C | Android 13+ engedély | `POST_NOTIFICATIONS` hiányzik a manifestből | jelen van | KibbiAi: `KibbiAi/android/app/src/main/AndroidManifest.xml:4` |
| D | iOS APNs entitlements | `Runner.entitlements` fájl nincs | `aps-environment=development`, `CODE_SIGN_ENTITLEMENTS` bekötve | KibbiAi: `KibbiAi/ios/Runner/Runner.entitlements` |
| E | APNs token race condition | `getToken()` direkt hívás, néha null iOS-en | 10×1mp `getAPNSToken()` polling + hibalog | KibbiAi: `KibbiAi_Shared/lib/core/push_notifications_helper.dart:130-148` |
| F | Token refresh | nincs `onTokenRefresh` listener | van, subscription cancel+resubscribe re-loginnál | KibbiAi: `PushNotificationsHelper` (`_tokenRefreshSub`) |
| G | Hibalogolás | csak `debugPrint` | `LogService`/`app_error_logs` insert strukturált context-tel | KibbiAi: `PushNotificationsHelper` |
| H | FCM hibarészlet | nincs eltárolva | `firstErrorDetail` (pl. `SENDER_ID_MISMATCH`) → `push_notification_logs.error_message` | KibbiAi HISTORY 2026-06-06 "Push hibák vizsgálata" |

**Megjegyzés:** az A pont kritikus — a legacy FCM endpoint már nem működik, tehát a Skeletonban a push valószínűleg jelenleg élesben sem küldhető ki.

---

## 3. Egyéb UI/UX fixek és konvenciók

### Lista csonkolás minta ("List Truncation Rule")
A KibbiAi CLAUDE.md 15. szekciója dokumentálja: minden 4 elemnél hosszabb lista esetén max 4 elem inline + "Továbbiak/Összes X (N)" pill gomb → `DraggableScrollableSheet` kereséssel, szűrő chipekkel, számláló badge-dzsel, "Nincs találat" üres állapottal.

Megvalósítások KibbiAi-ban:
- `KibbiAi/lib/screens/parent/child_edit_screen.dart`: `_AiCharacterPickerSheet` (1667. sor), `_ChatHistoryPickerSheet` (1382. sor), `_CategoryChip` (2003. sor)
- `KibbiAi_Admin/lib/screens/admin/security/security_screen.dart`: `_BannedIpsListSheet` (427), `_SecurityLogsListSheet` (528), `_SecChip` (310), `_wrapDraggable` (410)

A Skeletonban mindössze 2 `DraggableScrollableSheet` van (`security/banned_ips_sheet.dart` és `qa_shield/qa_shield_overlay.dart`), keresés/szűrés/üres állapot nélkül — a minta hiányzik.

### Flutter 3.x deprecation cleanup
A KibbiAi CLAUDE.md kötelezővé teszi: `.withValues(alpha:)` `withOpacity` helyett, `activeThumbColor` `activeColor` helyett. A KibbiAi_Shared-ben 45 `.withValues(alpha:)` és 0 `withOpacity` van. A Skeletonban viszont:

- **`withOpacity`** — 6 hely: `security_log_tile.dart` (68, 116, 122), `security_stats_row.dart` (118, 125), `banned_ips_sheet.dart` (92)
- **`activeColor`/`inactiveColor`** — 8 hely: `config_screen.dart` (164), `ai_screen.dart` (511), `settings_screen.dart` (270), `components_screen.dart` (266, 291, 308, 336, 337)

### Megosztott widget architektúra
A KibbiAi-nak van dedikált `KibbiAi_Shared` package-je (`brand_widgets.dart`, 2000+ sor: `GlassCard`, `KibbiTextField`, `KibbiButton`, `SquircleAvatar`, `GlassKeypad`, `RadialBackground`, `KibbiSessionCard`, `ParentBottomNav`, `ChatBubble`, `NotifBell`, `LiveCallVisualizer` stb.) — minden újrahasznosított UI egy helyen.

A Skeletonban a kliens (`Flutter/client/lib/core/components/`) és admin (`Flutter/admin/lib/core/components/`) appok **párhuzamos, csaknem azonos** komponenskészlettel rendelkeznek (`app_card.dart`, `app_button.dart`, `app_text_field.dart` stb.) — a változtatásokat duplán kell elvégezni.

---

## 4. Egyéb generalizálható fixek a HISTORY.md-ből (2026-06-06 körüli bejegyzések)

- **Üres chat session törlés**: `chat_cubit.dart` mostantól `_deleteSessionIfEmpty(sessionId)`-t hív `startNewSession()`/`close()`-on, törölve azokat a `chat_sessions`/`chat_messages` sorokat, ahol nincs felhasználói üzenet. Ha a Skeleton chat modulja hasonló mintát követ, ugyanaz a "üres session felhalmozódás" probléma valószínűleg ott is fennáll.
- **RLS migráció-konvenció**: a KibbiAi 012-es migrációja `DROP POLICY IF EXISTS … CREATE POLICY` mintát használ, hogy a migráció biztonságosan újrafuttatható legyen ("policy already exists" hiba elkerülése). Érdemes ezt konvencióként bevezetni minden új RLS-érintő Skeleton migrációnál.

---

## Összegzés — prioritási sorrend

1. **Push notification fixek (A–H)** — kritikus, mert a legacy FCM endpoint már nem működik éles környezetben.
2. **Admin screen szervezés** — közepes, jó kódminőség-javulás, nem sürgető.
3. **UI/UX konvenciók (lista csonkolás, deprecation cleanup)** — alacsony/közepes, főleg karbantarthatósági nyereség.
4. **Strukturális (megosztott package, migráció-konvenció)** — nagyobb döntést igénylő, hosszabb távú refaktor.
