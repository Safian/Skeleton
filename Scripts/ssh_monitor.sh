#!/bin/bash
# =============================================================
# ssh_monitor.sh – Sikeres root SSH bejelentkezés figyelő
#
# Figyeli az /var/log/auth.log fájlt és minden sikeres SSH
# bejelentkezésnél (különösen root) értesíti a Skeleton API-t.
#
# Telepítés (systemd service):
#   sudo cp ssh_monitor.sh /opt/skeleton/scripts/
#   sudo chmod +x /opt/skeleton/scripts/ssh_monitor.sh
#   sudo cp ssh_monitor.service /etc/systemd/system/
#   sudo systemctl enable --now ssh_monitor
# =============================================================

set -euo pipefail

# ── Konfig ────────────────────────────────────────────────────
ENV_FILE="/etc/fail2ban/skeleton.env"
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

API_URL="${SKELETON_API_URL:-}"
API_KEY="${SKELETON_API_KEY:-}"
LOG_FILE="${SSH_LOG_FILE:-/var/log/auth.log}"
MONITOR_ALL_USERS="${MONITOR_ALL_USERS:-false}"  # true = minden user, false = csak root

# ── Helpers ───────────────────────────────────────────────────
send_alert() {
  local event_type="$1"
  local ip="$2"
  local user="$3"
  local description="$4"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  [[ -z "$API_URL" || -z "$API_KEY" ]] && return 0

  curl -s -o /dev/null \
    -X POST "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"timestamp\":   \"$timestamp\",
      \"source\":      \"ssh_monitor\",
      \"event_type\":  \"$event_type\",
      \"ip_address\":  \"$ip\",
      \"description\": \"$description\",
      \"metadata\": {\"user\": \"$user\"}
    }" \
    --max-time 8 || true
}

# ── Auth log figyelő ──────────────────────────────────────────
# Minta: "Accepted publickey for root from 1.2.3.4 port 54321 ssh2"
# Minta: "Accepted password for deploy from 5.6.7.8 port 22222 ssh2"

tail -F "$LOG_FILE" 2>/dev/null | \
grep --line-buffered -E "Accepted (publickey|password) for" | \
while IFS= read -r line; do
  USER=$(echo "$line" | grep -oP 'for \K\S+')
  IP=$(echo "$line"   | grep -oP 'from \K[0-9a-f:.]+')
  METHOD=$(echo "$line" | grep -oP 'Accepted \K\S+')

  # Root bejelentkezés mindig riasztás
  if [[ "$USER" == "root" ]]; then
    send_alert \
      "successful_ssh_login" \
      "$IP" \
      "$USER" \
      "⚠️ Sikeres ROOT SSH bejelentkezés! Módszer: $METHOD, IP: $IP"
    echo "[ssh_monitor] ROOT login: $IP ($METHOD)"

  # Egyéb userek riasztása, ha konfigurálva
  elif [[ "$MONITOR_ALL_USERS" == "true" ]]; then
    send_alert \
      "successful_ssh_login" \
      "$IP" \
      "$USER" \
      "Sikeres SSH bejelentkezés: $USER. Módszer: $METHOD, IP: $IP"
    echo "[ssh_monitor] Login: $USER from $IP ($METHOD)"
  fi
done
