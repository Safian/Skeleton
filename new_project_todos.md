# Új projekt indítási teendők

## 1. Supabase projekt létrehozása

- [ ] Hozz létre új projektet a [Supabase Dashboardon](https://supabase.com/dashboard)
- [ ] Jegyezd fel a **Project ID**, **URL**, **anon key**, **service_role key** értékeket (Project Settings → API)

---

## 2. `.env` fájl kitöltése

A gyökérben lévő `.env` fájlban cseréld ki az alábbi értékeket:

```env
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
OPENAI_API_KEY=<openai-key>
```

> A `POSTGRES_PASSWORD`, `JWT_SECRET`, `REALTIME_SECRET` csak lokális stack esetén releváns.

---

## 3. Supabase adatbázis feltöltése

```bash
cd Supabase
supabase link --project-ref <project-id>
supabase db push
```

---

## 4. Email megerősítés KIKAPCSOLÁSA ⚠️

**Rögtön a db push után, még az első regisztráció előtt!**

Supabase Dashboard → **Authentication → Providers → Email** → "Confirm email" → **OFF**

Visszakapcsolni akkor kell, amikor:
- SMTP szerver be van állítva (Authentication → Settings → SMTP)
- Az email sablonok testre vannak szabva

---

## 5. Edge Functions deploy

```bash
supabase functions deploy --no-verify-jwt
supabase secrets set OPENAI_API_KEY=<openai-key>
```

---

## 6. Storage bucket létrehozása

```bash
curl -X POST "https://<project-id>.supabase.co/storage/v1/bucket" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"id":"bug-screenshots","name":"bug-screenshots","public":false}'
```

---

## 7. Flutter appok indítása + első admin regisztráció

```bash
./Scripts/start_local.sh flutter
```

- Client: http://localhost:3000
- Admin: http://localhost:3001

Az első regisztrált felhasználó automatikusan **admin** szerepet kap (DB trigger).

---

## 8. Ha mégis kellene manuálisan megerősíteni egy usert

```bash
curl -X PUT "https://<project-id>.supabase.co/auth/v1/admin/users/<user-id>" \
  -H "Authorization: Bearer <service-role-key>" \
  -H "apikey: <service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"email_confirm": true}'
```
