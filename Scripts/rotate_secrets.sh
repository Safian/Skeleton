#!/usr/bin/env bash
#
# rotate_secrets.sh – Erős, véletlenszerű secret-ek generálása az .env fájlba.
#
# Lecseréli a POSTGRES_PASSWORD, JWT_SECRET és REALTIME_SECRET értékeit
# kriptográfiailag erős, megfelelő formátumú stringekre – DE csak akkor, ha:
#   1) a változót valóban használja a Supabase docker-compose stack, ÉS
#   2) az aktuális érték üres VAGY a közismert demo/alap érték
#      (azaz "érdemes" generálni – egy már egyedi értéket nem ír felül).
#
# Használat:
#   Scripts/rotate_secrets.sh            # csere helyben, .env.bak mentéssel
#   Scripts/rotate_secrets.sh --dry-run  # csak megmutatja, mit tenne
#   Scripts/rotate_secrets.sh --force    # egyedi értékeket is felülír
#   Scripts/rotate_secrets.sh /path/.env # másik .env fájlra
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=0
FORCE=0
ENV_FILE="$ROOT_DIR/.env"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    -*)        echo "Ismeretlen kapcsoló: $arg" >&2; exit 2 ;;
    *)         ENV_FILE="$arg" ;;
  esac
done

# A docker-compose fájlok, ahol a változók használatát keressük
COMPOSE_FILES=( "$ROOT_DIR"/Supabase/docker-compose*.yml )

# Közismert demo/alap értékek, amelyeket biztonságos felülírni
DEFAULT_POSTGRES_PASSWORD="postgres"
DEFAULT_JWT_SECRET="super-secret-jwt-token-with-at-least-32-chars-local-dev-only"
DEFAULT_REALTIME_SECRET="UpNVntn3cDxHJpq99YMc1T1AQgQpc8kfYTuRgBiYa15BLrx8etQoXz3P5OuDCBxr"

# ── Előfeltételek ────────────────────────────────────────────────────────────
command -v openssl >/dev/null 2>&1 || { echo "❌ openssl szükséges." >&2; exit 1; }
[ -f "$ENV_FILE" ] || { echo "❌ Nincs .env fájl: $ENV_FILE" >&2; exit 1; }

# ── Segédfüggvények ──────────────────────────────────────────────────────────

# Aktuális érték kiolvasása (= utáni rész, idézőjelek nélkül)
current_value() {
  local key="$1"
  grep -E "^${key}=" "$ENV_FILE" | head -1 | cut -d= -f2- | sed -E 's/^["'\'']//; s/["'\'']$//'
}

# Használja-e bármelyik compose fájl ezt a változót?
is_used() {
  local key="$1"
  grep -qE "\\\$\{?${key}[:}-]" "${COMPOSE_FILES[@]}" 2>/dev/null
}

# A KEY=... sor cseréje a régi értéktől függetlenül (awk, biztonságos)
replace_in_env() {
  local key="$1" val="$2" tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v val="$val" -F= '
    $1==key { print key"="val; next }
    { print }
  ' "$ENV_FILE" > "$tmp"
  mv "$tmp" "$ENV_FILE"
}

# Egy secret feldolgozása: key, default-érték, generátor-parancs
process_secret() {
  local key="$1" default="$2" generator="$3"
  local cur new

  if ! is_used "$key"; then
    echo "  ⏭️  $key – egyik compose fájl sem használja, kihagyva."
    return
  fi

  cur="$(current_value "$key")"

  if [ "$FORCE" -ne 1 ] && [ -n "$cur" ] && [ "$cur" != "$default" ]; then
    echo "  ✅ $key – már egyedi érték, megtartva (--force a felülíráshoz)."
    return
  fi

  new="$(eval "$generator")"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  🔎 $key – cserélné erre: ${new:0:12}… (${#new} karakter)"
    return
  fi

  replace_in_env "$key" "$new"
  echo "  🔐 $key – új érték generálva (${#new} karakter)."
  CHANGED+=("$key")
}

# ── Futás ────────────────────────────────────────────────────────────────────
echo "🔑 Secret rotáció: $ENV_FILE"
[ "$DRY_RUN" -eq 1 ] && echo "   (dry-run – nem ír semmit)"

# Biztonsági mentés (csak valódi futásnál)
if [ "$DRY_RUN" -ne 1 ]; then
  cp "$ENV_FILE" "${ENV_FILE}.bak"
  echo "   Mentés: ${ENV_FILE}.bak"
fi

CHANGED=()

# Postgres jelszó: 48 hex karakter – connection-string-biztos (nincs speciális char)
process_secret "POSTGRES_PASSWORD" "$DEFAULT_POSTGRES_PASSWORD" "openssl rand -hex 24"

# JWT secret: 64 hex karakter (a GoTrue >= 32-t követel)
process_secret "JWT_SECRET" "$DEFAULT_JWT_SECRET" "openssl rand -hex 32"

# Realtime secret: 64 hex karakter
process_secret "REALTIME_SECRET" "$DEFAULT_REALTIME_SECRET" "openssl rand -hex 32"

# ── JWT figyelmeztetés ───────────────────────────────────────────────────────
if printf '%s\n' "${CHANGED[@]:-}" | grep -q "JWT_SECRET"; then
  cat <<'WARN'

⚠️  FONTOS: a JWT_SECRET megváltozott.
    A SUPABASE_ANON_KEY és a SUPABASE_SERVICE_ROLE_KEY ezzel a secrettel
    aláírt JWT-k – a régi kulcsok mostantól ÉRVÉNYTELENEK. Generálj újakat
    (pl. supabase CLI vagy a jwt.io a payload + új secret alapján), és
    frissítsd őket az .env-ben, mielőtt újraindítod a stacket.
WARN
fi

echo "✅ Kész."
