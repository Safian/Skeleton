# Admin modul – kód review

> Dátum: 2026-06-05  
> Scope: `Flutter/admin/lib/**`

---

## 1. Bugok (kritikus)

### 1.1 `setDefaultAiModel` – korábbi default nem törlődik

**Fájl:** `lib/repositories/admin_repository.dart:235`

```dart
Future<void> setDefaultAiModel(String id) async {
  await _db.from('ai_models').update({'is_default': true}).eq('id', id);
}
```

Csak az új modellt jelöli default-nak, a korábbit nem kapcsolja le. Eredmény: egyszerre több `is_default: true` sor az adatbázisban.

**Fix:**
```dart
await _db.from('ai_models').update({'is_default': false});
await _db.from('ai_models').update({'is_default': true}).eq('id', id);
```
(Vagy egy DB-szintű trigger/policy, ami biztosítja az egyediséget.)

---

### 1.2 `updateLegalDocument` – önmagát deaktiválja

**Fájl:** `lib/repositories/admin_repository.dart:172`

```dart
if (doc.isActive) {
  await _db.from('legal_documents')
      .update({'is_active': false})
      .eq('id', doc.id);  // ← saját ID-re szűr!
}
```

A szándék valószínűleg az, hogy más verziókat deaktiváljon, de az `.eq('id', doc.id)` pontosan azt a sort kapcsolja ki, amit aztán az upsert visszakapcsol. Más verziók aktívak maradnak.

**Fix:** szűrj `id`-re ÉS arra, hogy ne a mentendő verzió legyen:
```dart
await _db.from('legal_documents')
    .update({'is_active': false})
    .eq('id', doc.id)
    .neq('version', doc.version);
```

---

### 1.3 `DeepLinksScreen` – TextController memory leak

**Fájl:** `lib/screens/home/deep_links/deep_links_screen.dart:358`

```dart
...List.generate(_mappings.length, (i) {
  final pathCtrl  = TextEditingController(text: m['path']);
  final actCtrl   = TextEditingController(text: m['action']);
  final descCtrl  = TextEditingController(text: m['description']);
  // Soha nincs dispose()-olva!
```

Minden `build()` hívásnál 3 × N új `TextEditingController` keletkezik, dispose hívás nélkül. Memory leak.

**Fix:** Vezess be egy állapotot, ami tárolja a controllereket (`initState`-ben), és `dispose()`-olj minden sort törlésnél/dispose-nál.

---

### 1.4 `_WellKnownStatus` – relatív URL-ek nem működnek HTTP kérésben

**Fájl:** `lib/screens/home/deep_links/deep_links_screen.dart:509`

```dart
_check('/.well-known/apple-app-site-association', true)
_check('/.well-known/assetlinks.json', false)
```

Az `http.get(Uri.parse('/.well-known/...'))` relatív URI-t nem tud feloldani hálózati kérésben – hibát dob vagy a localhost-hoz próbál csatlakozni. Hiányzik a base URL.

**Fix:** Olvasd ki az app URL-t `app_settings`-ből (pl. `app_base_url` kulcs), és fűzd elé.

---

### 1.5 `DatabaseScreen` – 5000 sor lekérése count helyett

**Fájl:** `lib/screens/home/database/database_screen.dart:44`

```dart
final res = await _db.from(t).select().limit(5000);
return _TableInfo(name: t, rowCount: (res as List).length, reachable: true);
```

5000 sort tölt le táblánként csak a sor számának meghatározásához. Nagy tábláknál (user_profiles, gpt_usage_logs) ez lassú, pazarló, és pontatlan is (ha >5000 sor van, `5000`-t fog mutatni).

**Fix:** Használj `count` paramétert:
```dart
final res = await _db.from(t).select('*', const FetchOptions(count: CountOption.exact)).limit(1);
final rowCount = res.count ?? 0;
```

---

### 1.6 `fetchAppSettings` – gyanús async minta

**Fájl:** `lib/repositories/admin_repository.dart:193`

```dart
return (_db.from('app_settings').select().order('id') as dynamic)
    .then((r) => (r as List).cast<Map<String, dynamic>>());
```

A query `dynamic`-ra castolva, `.then()` lánccal kezelve – nem `await`. Ha a belső cast hibát dob, a kivétel elveszik. Minden más metódus `await`-et használ.

**Fix:**
```dart
final res = await _db.from('app_settings').select().order('id');
return (res as List).cast<Map<String, dynamic>>();
```

---

## 2. Befejezetlen funkciók

### 2.1 `NotificationsScreen` – egyedi felhasználóra küldés nem megvalósított

**Fájl:** `lib/screens/home/notifications/notifications_screen.dart`

A `_targetUserId` field és az edge function `target_user_id` paramétere létezik a kódban, de nincs olyan UI elem, ahol be lehetne állítani. A `_targetUserId` értéke örökre `null` marad. A dropdown `user` opció teljes egészében hiányzik.

**Tennivaló:** Vagy add hozzá a user-keresős beviteli mezőt, vagy távolítsd el a `_targetUserId` field-et és a `'user'` branch-et az edge function hívásból.

---

### 2.2 `SettingsScreen` – 3 gomb üres handler

**Fájl:** `lib/screens/home/settings/settings_screen.dart:73`

```dart
SettingsListTile(title: 'Adatbázis', subtitle: 'Supabase Studio megnyitása', onTap: () {},)
SettingsListTile(title: 'Rendszer naplók', onTap: () {},)
SettingsListTile(title: 'Értesítések', onTap: () {},)
```

Mind kattintható megjelenítéssel bír, de semmit sem csinál. Felhasználó szempontjából törött funkciók.

**Tennivaló:** Navigálj a megfelelő tabra (via drawer index), vagy távolítsd el, amíg nincs megvalósítva.

---

### 2.3 `SettingsScreen` – hardcoded verziószám

**Fájl:** `lib/screens/home/settings/settings_screen.dart:99`

```dart
subtitle: '1.0.0',
```

A `HomeScreen` dinamikusan olvassa `PackageInfo.fromPlatform()`-ból, de a `SettingsScreen` statikusan `'1.0.0'`-t mutat.

---

### 2.4 `AdminCubit` – felesleges teljes reload minden mutációnál

**Fájl:** `lib/blocs/admin/admin_cubit.dart`

`createTranslation`, `updateTranslation`, `deleteTranslation`, `updateLegalDocument` – mind `await initAdmin()`-t hívnak, ami párhuzamosan lekéri az összes felhasználót, fordítást és jogi dokumentumot. Egyetlen fordítás létrehozásához 3 Supabase query fut.

**Fix:** Mutáció után csak a releváns listát töltsd újra (`fetchAllTranslations()` / `fetchAllLegalDocuments()`), vagy optimista frissítést alkalmazz.

---

## 3. Dead code

| # | Hol | Mi | Miért dead |
|---|-----|----|------------|
| 3.1 | `security_repository.dart:96` | `watchLogs()` stream | Megvalósítva, de a `SecurityCubit` és a screen sosem hívja |
| 3.2 | `notifications_screen.dart:27` | `String? _targetUserId` | Deklarálva, értéke mindig `null` marad (lásd 2.1) |
| 3.3 | `main.dart:81` | `translationState` builder paraméter | A `BlocBuilder` csak rebuild-et triggerel, de `translationState`-t nem használja (pl. locale beállításhoz) |
| 3.4 | `admin_cubit.dart` – `AdminLoaded` state | Az `AdminCubit` adatait (`users`, `translations`, `legalDocuments`) a screen-ek nem olvassák; saját repository hívásokat csinálnak | Unused BLoC state |
| 3.5 | `notifications_screen.dart:21` | `final _db = Supabase.instance.client` | Van `_repo = AdminRepository()` is; a direkt client inkonzisztens a repository pattern-nel |

---

## Összefoglalás

| Kategória | Db |
|-----------|-----|
| Kritikus bug | 6 |
| Befejezetlen funkció | 4 |
| Dead code | 5 |

**Legsürgősebb:** 1.1 (`setDefaultAiModel`), 1.2 (`updateLegalDocument`), 1.3 (TextController leak).
