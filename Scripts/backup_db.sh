#!/bin/bash
# =============================================================
# backup_db.sh – Automatizált titkosított Supabase DB backup
#
# Mentést készít a PostgreSQL adatbázisról és feltölti S3-ra.
# Titkosítás: OpenSSL AES-256-CBC
#
# Crontab beállítás (minden éjjel 2:00-kor):
#   0 2 * * * /opt/skeleton/scripts/backup_db.sh >> /var/log/skeleton/backup.log 2>&1
#
# Szükséges eszközök: pg_dump, openssl, aws (AWS CLI vagy s3cmd)
# =============================================================

set -euo pipefail

# ── Konfig ────────────────────────────────────────────────────
ENV_FILE="/opt/supabase/docker/.env"
BACKUP_ENV="/opt/skeleton/backup.env"

# Alap Supabase env betöltése
[[ -f "$ENV_FILE" ]]    && source "$ENV_FILE"
[[ -f "$BACKUP_ENV" ]]  && source "$BACKUP_ENV"

# Szükséges változók
: "${POSTGRES_DB:=postgres}"
: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set}"
: "${POSTGRES_HOST:=localhost}"
: "${POSTGRES_PORT:=5432}"
: "${BACKUP_ENCRYPTION_KEY:?BACKUP_ENCRYPTION_KEY not set}"
: "${S3_BUCKET:?S3_BUCKET not set}"
: "${S3_ENDPOINT:=}"  # üres = AWS default
: "${S3_REGION:=eu-central-1}"
: "${BACKUP_RETAIN_DAYS:=30}"

# Supabase API konfig (Telegram riasztáshoz)
TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT="${TELEGRAM_CHAT_ID:-}"

# Supabase API (backup log íráshoz)
SUPABASE_URL="${SUPABASE_PUBLIC_URL:-}"
SUPABASE_SERVICE_KEY="${SERVICE_ROLE_KEY:-}"

# ── Könyvtárak ────────────────────────────────────────────────
BACKUP_DIR="/tmp/skeleton_backups"
LOG_DIR="/var/log/skeleton"
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/db_${TIMESTAMP}.sql.gz.enc"
S3_KEY="backups/db/db_${TIMESTAMP}.sql.gz.enc"

# ── Helpers ───────────────────────────────────────────────────
log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"; }

send_telegram() {
  local msg="$1"
  [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT" ]] && return 0
  curl -s -o /dev/null -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$TELEGRAM_CHAT\",\"text\":\"$msg\",\"parse_mode\":\"Markdown\"}" \
    --max-time 10 || true
}

write_supabase_log() {
  local status="$1" duration="$2" size="$3" error="${4:-}"
  [[ -z "$SUPABASE_URL" || -z "$SUPABASE_SERVICE_KEY" ]] && return 0
  curl -s -o /dev/null -X POST \
    "${SUPABASE_URL}/rest/v1/backup_logs" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{
      \"backup_type\":   \"database\",
      \"status\":        \"$status\",
      \"duration_secs\": $duration,
      \"size_bytes\":    $size,
      \"s3_path\":       \"$S3_KEY\",
      \"triggered_by\":  \"cron\",
      \"error_message\": $([ -n \"$error\" ] && echo \"\\\"$error\\\"\" || echo 'null')
    }" \
    --max-time 10 || true
}

# ── Cleanup függvény ──────────────────────────────────────────
cleanup() {
  rm -f "$BACKUP_FILE" "${BACKUP_FILE%.enc}" 2>/dev/null || true
}
trap cleanup EXIT

# ── START ─────────────────────────────────────────────────────
log "=== Backup indítása ==="
START_TIME=$(date +%s)

# 1) pg_dump → gzip → titkosítás
log "pg_dump futtatása..."
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --no-owner \
  --no-acl \
  --format=plain \
  --schema=public \
  2>>"$LOG_DIR/backup_err.log" | \
  gzip | \
  openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
    -pass "pass:${BACKUP_ENCRYPTION_KEY}" \
    -out "$BACKUP_FILE"

BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || stat -f%z "$BACKUP_FILE")
log "Backup méret: $(( BACKUP_SIZE / 1024 / 1024 )) MB"

# 2) S3 feltöltés
log "S3 feltöltés: s3://$S3_BUCKET/$S3_KEY"

if command -v aws &>/dev/null; then
  AWS_ARGS="--region $S3_REGION"
  [[ -n "$S3_ENDPOINT" ]] && AWS_ARGS="$AWS_ARGS --endpoint-url $S3_ENDPOINT"
  # shellcheck disable=SC2086
  aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/$S3_KEY" $AWS_ARGS
elif command -v s3cmd &>/dev/null; then
  S3CMD_ARGS=""
  [[ -n "$S3_ENDPOINT" ]] && S3CMD_ARGS="--host=$S3_ENDPOINT --host-bucket=%"
  # shellcheck disable=SC2086
  s3cmd put "$BACKUP_FILE" "s3://$S3_BUCKET/$S3_KEY" $S3CMD_ARGS
else
  log "ERROR: sem aws CLI, sem s3cmd nem található!" >&2
  exit 1
fi

# 3) Régi backupok törlése S3-ról
log "Régi backupok törlése (>${BACKUP_RETAIN_DAYS} nap)..."
CUTOFF_DATE=$(date -u -d "-${BACKUP_RETAIN_DAYS} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              date -u -v "-${BACKUP_RETAIN_DAYS}d" +"%Y-%m-%dT%H:%M:%SZ")

if command -v aws &>/dev/null; then
  AWS_ARGS="--region $S3_REGION"
  [[ -n "$S3_ENDPOINT" ]] && AWS_ARGS="$AWS_ARGS --endpoint-url $S3_ENDPOINT"
  # shellcheck disable=SC2086
  aws s3 ls "s3://$S3_BUCKET/backups/db/" $AWS_ARGS | \
    awk '{print $4}' | \
    while read -r obj; do
      OBJ_DATE=$(echo "$obj" | grep -oP '\d{8}_\d{6}' | \
                 sed 's/\(.\{4\}\)\(.\{2\}\)\(.\{2\}\)_\(.\{2\}\)\(.\{2\}\)\(.\{2\}\)/\1-\2-\3T\4:\5:\6Z/')
      if [[ "$OBJ_DATE" < "$CUTOFF_DATE" ]]; then
        aws s3 rm "s3://$S3_BUCKET/backups/db/$obj" $AWS_ARGS || true
        log "Törölve: $obj"
      fi
    done
fi

# ── Befejezés ─────────────────────────────────────────────────
END_TIME=$(date +%s)
DURATION=$(( END_TIME - START_TIME ))
log "=== Backup kész: ${DURATION}s, ${BACKUP_SIZE} byte ==="

write_supabase_log "success" "$DURATION" "$BACKUP_SIZE"
send_telegram "✅ *DB Backup sikeres*
Méret: $(( BACKUP_SIZE / 1024 / 1024 )) MB | Idő: ${DURATION}s
Útvonal: \`$S3_KEY\`"
