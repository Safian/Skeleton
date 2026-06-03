# Skeleton App – Beállítási útmutató

## ⚙️ Előkészítés (AI számára)

Ha ezt a projektet lemásolod és AI-jal programozod tovább, kérd be az alábbi értékeket:

### 1. Supabase konfiguráció
```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJhbGci...
```
Ezeket írd be a `Flutter/.env` fájlba.

### 2. App névcsere
- `skeleton_app` → `pubspec.yaml` `name:` mezője
- `Skeleton App` → `main.dart` MaterialApp `title:` és SplashScreen szövege
- A logó placeholder: `lib/screens/splash_screen.dart` és `auth_screen.dart`

---

## 🚀 Gyors indítás

### Flutter app
```bash
cd Flutter
flutter pub get
flutter run
```

### Supabase (lokál – CLI módszer, ajánlott)
```bash
cd Supabase
# Ha nincs Supabase CLI: https://supabase.com/docs/guides/cli
supabase start
# Kimenetből másold ki az anon key-t és URL-t a .env-be
```

### Supabase (Docker Compose módszer)
```bash
cd Supabase
cp .env.example .env
# Töltsd ki az .env fájlt
docker-compose up -d
# Studio: http://localhost:54323
```

---

## 📁 Projekt struktúra

```
Skeleton/
├── Flutter/
│   ├── .env                          ← Supabase credentials
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart                 ← Belépési pont + routing
│       ├── core/
│       │   ├── theme/               ← Teljes design system
│       │   │   ├── app_theme.dart   ← Material ThemeData factory
│       │   │   ├── app_colors.dart  ← Color tokens
│       │   │   ├── app_typography.dart
│       │   │   └── app_sizes.dart
│       │   └── components/          ← Újrafelhasználható komponensek
│       │       ├── app_button.dart
│       │       ├── app_text_field.dart
│       │       ├── app_card.dart
│       │       ├── app_badge.dart
│       │       ├── app_avatar.dart
│       │       ├── app_list_tile.dart
│       │       ├── app_background.dart
│       │       └── components.dart  ← Barrel export
│       ├── models/
│       │   ├── user_profile.dart
│       │   └── item.dart            ← Demo model (cseréld le)
│       ├── repositories/
│       │   ├── auth_repository.dart
│       │   └── items_repository.dart ← Demo repo (cseréld le)
│       ├── blocs/
│       │   ├── session/             ← Global auth state
│       │   ├── auth/                ← Login form state
│       │   └── items/               ← Lista state (demo)
│       └── screens/
│           ├── splash_screen.dart
│           ├── auth/auth_screen.dart
│           └── home/
│               ├── home_screen.dart ← 4 tab keret
│               ├── dashboard/       ← Tab 1 (dummy)
│               ├── list/            ← Tab 2 + detail screen
│               ├── components_showcase/ ← Tab 3
│               └── settings/        ← Tab 4
└── Supabase/
    ├── docker-compose.yml
    ├── .env.example
    └── supabase/
        ├── config.toml
        ├── seed.sql
        └── migrations/
            ├── 001_user_profiles.sql
            └── 002_items.sql
```

---

## 🔧 Testre szabás lépései

1. **Projekt neve**: `pubspec.yaml` → `name:`, `MaterialApp` → `title:`
2. **Színek**: `core/theme/app_colors.dart` → `AppColorPalette.dark`
3. **Betűtípus**: `core/theme/app_typography.dart` → `GoogleFonts.*`
4. **Logo**: `SplashScreen` és `AuthScreen` logo widgetek
5. **Modellek**: `item.dart` és `items_repository.dart` lecserélése
6. **Dashboard**: `dashboard_screen.dart` valódi adatokra cserélése
7. **Supabase migrációk**: `002_items.sql` → valódi tábla szerkezet

---

## 🏗️ Architektúra

| Réteg | Technológia | Szerepe |
|-------|------------|---------|
| State | flutter_bloc (Cubit) | Üzleti logika |
| Data | Repository pattern | Supabase CRUD |
| Auth | SessionCubit | Globális auth state |
| UI | Material 3 + custom theme | Megjelenés |
| Config | flutter_dotenv | .env kezelés |
