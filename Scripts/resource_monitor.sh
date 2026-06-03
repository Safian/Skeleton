#!/bin/bash
# =============================================================
# resource_monitor.sh – CPU/RAM/Disk figyelő Telegram riasztással
#
# Crontab (minden 5 percben ellenőrzés, 15 percenként snapshot):
#   */5  * * * * /opt/skeleton/scripts/resource_monitor.sh check
#   */15 * * * * /opt/skeleton/scripts/resource_monitor.sh snapshot
# =============================================================

set -euo pipefail

# ── Konfig ────────────────────────────────────────────────────
ENV_FILE="/opt/skeleton/backup.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

TELEGRAM_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT="${TELEGRAM_CHAT_ID:-}"
SUPABASE_URL="${SUPABASE_PUBLIC_URL:-}"
SUPABASE_SERVICE_KEY="${SERVICE_ROLE_KEY:-}"

DISK_ALERT_THRESHOLD="${DISK_ALERT_THRESHOLD:-85}"
RAM_ALERT_THRESHOLD="${RAM_ALERT_THRESHOLD:-90}"
CPU_ALERT_THRESHOLD="${CPU_ALERT_THRESHOLD:-95}"

# Rate limiting: ne küldjünk ugyanarról a problémáról 1 órán belül kétszer
ALERT_LOCK_DIR="/tmp/skeleton_monitor_locks"
mkdir -p "$ALERT_LOCK_DIR"

ACTION="${1:-check}"

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

rate_limited_alert() {
  local key="$1" msg="$2"
  local lock_file="$ALERT_LOCK_DIR/$key"
  # Ha a lock fájl 1 óránál frissebb, skip
  if [[ -f "$lock_file" ]]; then
    local age=$(( $(date +%s) - $(stat -c%Y "$lock_file" 2>/dev/null || stat -f%m "$lock_file") ))
    [[ "$age" -lt 3600 ]] && return 0
  fi
  touch "$lock_file"
  send_telegram "$msg"
  log "ALERT küldve: $key"
}

write_snapshot() {
  local cpu="$1" ram_used="$2" ram_total="$3" disk_used="$4" disk_total="$5" disk_pct="$6"
  [[ -z "$SUPABASE_URL" || -z "$SUPABASE_SERVICE_KEY" ]] && return 0
  curl -s -o /dev/null -X POST \
    "${SUPABASE_URL}/rest/v1/resource_snapshots" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{
      \"cpu_percent\":   $cpu,
      \"ram_used_mb\":   $ram_used,
      \"ram_total_mb\":  $ram_total,
      \"disk_used_gb\":  $disk_used,
      \"disk_total_gb\": $disk_total,
      \"disk_percent\":  $disk_pct
    }" \
    --max-time 10 || true
}

# ── Metrikák gyűjtése ─────────────────────────────────────────
get_cpu_percent() {
  # 1 másodperces mintavétel
  top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'.' -f1 2>/dev/null || \
  grep -c processor /proc/cpuinfo | xargs -I{} awk 'NR==1{print int(100-$NF)}' /proc/loadavg 2>/dev/null || \
  echo "0"
}

get_ram() {
  # Visszaad: used_mb total_mb percent
  free -m 2>/dev/null | awk '/^Mem:/{
    used=$3; total=$2;
    pct=int(used*100/total);
    print used, total, pct
  }' || echo "0 0 0"
}

get_disk() {
  # / partíció: used_gb total_gb percent
  df -BG / 2>/dev/null | awk 'NR==2{
    gsub(/G/,"",$3); gsub(/G/,"",$2); gsub(/%/,"",$5);
    print $3, $2, $5
  }' || echo "0 0 0"
}

# ── CHECK akció ───────────────────────────────────────────────
do_check() {
  CPU=$(get_cpu_percent)
  read -r RAM_USED RAM_TOTAL RAM_PCT <<< "$(get_ram)"
  read -r DISK_USED DISK_TOTAL DISK_PCT <<< "$(get_disk)"

  log "CPU: ${CPU}% | RAM: ${RAM_USED}/${RAM_TOTAL} MB (${RAM_PCT}%) | Disk: ${DISK_USED}/${DISK_TOTAL} GB (${DISK_PCT}%)"

  # Disk riasztás
  if [[ "$DISK_PCT" -ge "$DISK_ALERT_THRESHOLD" ]]; then
    rate_limited_alert "disk_alert" "⚠️ *TÁRHELY RIASZTÁS*
💾 Felhasználva: ${DISK_PCT}% (${DISK_USED}/${DISK_TOTAL} GB)
Küszöb: ${DISK_ALERT_THRESHOLD}%
Szerver: \`$(hostname)\`"
  fi

  # RAM riasztás
  if [[ "$RAM_PCT" -ge "$RAM_ALERT_THRESHOLD" ]]; then
    rate_limited_alert "ram_alert" "⚠️ *RAM RIASZTÁS*
🧠 Felhasználva: ${RAM_PCT}% (${RAM_USED}/${RAM_TOTAL} MB)
Küszöb: ${RAM_ALERT_THRESHOLD}%
Szerver: \`$(hostname)\`"
  fi

  # CPU riasztás
  if [[ "$CPU" -ge "$CPU_ALERT_THRESHOLD" ]]; then
    rate_limited_alert "cpu_alert" "⚠️ *CPU RIASZTÁS*
⚙️ Terhelés: ${CPU}%
Küszöb: ${CPU_ALERT_THRESHOLD}%
Szerver: \`$(hostname)\`"
  fi
}

# ── SNAPSHOT akció ────────────────────────────────────────────
do_snapshot() {
  CPU=$(get_cpu_percent)
  read -r RAM_USED RAM_TOTAL RAM_PCT <<< "$(get_ram)"
  read -r DISK_USED DISK_TOTAL DISK_PCT <<< "$(get_disk)"
  write_snapshot "$CPU" "$RAM_USED" "$RAM_TOTAL" "$DISK_USED" "$DISK_TOTAL" "$DISK_PCT"
  log "Snapshot mentve."
}

# ── Főprogram ─────────────────────────────────────────────────
case "$ACTION" in
  check)    do_check    ;;
  snapshot) do_snapshot ;;
  both)     do_check; do_snapshot ;;
  *)
    echo "Használat: $0 [check|snapshot|both]" >&2
    exit 1
    ;;
esac
