# Implementációs terv — Flutter 3.x deprecation cleanup lezárása

## Háttér
A `.withOpacity` → `.withValues(alpha:)` csere már kész mindkét projektben (Skeleton, KibbiAi).
Az `activeColor` → `activeThumbColor` csere a `Switch`/`SwitchListTile` widgeteken most készült el:
- Skeleton: 4 helyen (settings_screen.dart, components_screen.dart x2, ai_screen.dart, config_screen.dart)
- KibbiAi: nem volt érintett Switch/SwitchListTile előfordulás

(Megjegyzés: `Checkbox`, `Slider`, `CheckboxListTile` widgeteken az `activeColor` NEM deprecated, ott szándékosan maradt érintetlen.)

## Hátralévő lépések

### 1. HISTORY.md bejegyzés (KibbiAi)
Írj egy új changelog bejegyzést a `KibbiAi/HISTORY.md` tetejére (NEM a végére!) a mai dátummal (2026-06-06), ami dokumentálja:
- Az `activeColor` → `activeThumbColor` migrációt a Switch/SwitchListTile widgeteken
- Az érintett fájlokat
- Hogy a Checkbox/Slider/CheckboxListTile szándékosan maradt változatlan

### 2. Static analysis ellenőrzés
Futtasd le mindkét projektben:
```bash
flutter analyze --no-fatal-infos
```
- Skeleton: `Flutter/client/` és `Flutter/admin/`
- KibbiAi: `KibbiAi/`, `KibbiAi_Admin/`, `KibbiAi_Shared/`

Cél: győződj meg róla, hogy nincs más Flutter 3.x deprecation warning (pl. `withOpacity`, `activeColor`, egyéb API változás), amit a static analyzer kidob.

### 3. Függő migrációk (Skeleton)
A Skeleton projektben két migráció vár alkalmazásra:
- `018`: Realtime explicit publikáció
- `019`: Deferred deep link `pending_invites` tábla

Mindkettőhöz `supabase db push` szükséges. Ellenőrizd a migrációs fájlok tartalmát, majd futtasd le őket a megfelelő Supabase projekten.

## Verifikáció
- `flutter analyze` tiszta futás (nincs deprecation warning)
- `git diff` átnézése: csak a tervezett `activeColor`→`activeThumbColor` cserék szerepelnek, semmi nem sérült
- Migrációk után `supabase migration list` ellenőrzi, hogy 018/019 alkalmazva van
