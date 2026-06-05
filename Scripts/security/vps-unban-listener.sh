#!/usr/bin/env bash
# ============================================================
# VPS Unban Listener – HTTP mini-szerver
# ============================================================
# Egy egyszerű netcat/socat alapú HTTP listener, ami fogad
# POST /unban hívásokat a Supabase edge function-tól, és
# végrehajtja a fail2ban-client unban parancsot.
#
# TELEPÍTÉS:
#   1. apt-get install -y socat fail2ban
#   2. cp vps-unban-listener.sh /etc/security-monitor/
#   3. chmod +x /etc/security-monitor/vps-unban-listener.sh
#   4. Systemd service-ként futtatni (lásd: unban-listener.service)
#
# FONTOS BIZTONSÁGI MEGJEGYZÉS:
#   Ez a listener csak localhost-on vagy zárt hálózaton
#   hallgatózzon! A VPS firewall-ján CSAK a Supabase edge
#   function-k IP tartományát engedd be erre a portra,
#   VAGY használj WireGuard/Tailscale tunnelt.
#   Supabase funkcióinak IP-i: https://supabase.com/docs/guides/functions
# ============================================================

set -euo pipefail

CONFIG_FILE="/etc/security-monitor/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

PORT="${UNBAN_LISTENER_PORT:-9090}"
LOGFILE="/var/log/security-monitor/unban-listener.log"
UNBAN_SECRET="${UNBAN_LISTENER_SECRET:-}"
mkdir -p "$(dirname "$LOGFILE")"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" | tee -a "$LOGFILE"; }

log "Unban listener indul, port: $PORT"

# ── Request handler ────────────────────────────────────────────
handle_request() {
  local raw_request=""
  local content_length=0
  local body=""
  local ip_address=""
  local jail="sshd"
  local auth_header=""

  # HTTP fejléc beolvasása
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && break
    if [[ "$line" =~ ^Content-Length:\ ([0-9]+) ]]; then
      content_length="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ ^X-Unban-Secret:\ (.+) ]]; then
      auth_header="${BASH_REMATCH[1]}"
    fi
  done

  # Body beolvasása
  if [[ "$content_length" -gt 0 ]]; then
    body=$(dd bs=1 count="$content_length" 2>/dev/null)
  fi

  log "Kapott body: $body"

  # Secret ellenőrzés (ha be van állítva)
  if [[ -n "$UNBAN_SECRET" && "$auth_header" != "$UNBAN_SECRET" ]]; then
    log "WARN: Unauthorized unban request (wrong or missing X-Unban-Secret)"
    printf 'HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\n\r\n{"error":"unauthorized"}'
    return
  fi

  # JSON parse (jq nélkül, egyszerű grep/sed)
  ip_address=$(echo "$body" | grep -oP '"ip_address"\s*:\s*"\K[^"]+' || true)
  jail=$(echo "$body"       | grep -oP '"jail"\s*:\s*"\K[^"]+'       || echo "sshd")

  if [[ -z "$ip_address" ]]; then
    log "HIBA: ip_address hiányzik"
    printf 'HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n{"error":"missing ip_address"}'
    return
  fi

  # ── fail2ban unban ─────────────────────────────────────────
  log "Unban: $ip_address (jail: $jail)"

  if fail2ban-client set "$jail" unbanip "$ip_address" 2>>"$LOGFILE"; then
    log "Sikeres unban: $ip_address"
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"ok":true,"ip":"%s"}' "$ip_address"
  else
    log "WARN: fail2ban-client sikertelen (lehet, hogy az IP már nem volt tiltva)"
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"ok":true,"warn":"ip_not_found_in_jail","ip":"%s"}' "$ip_address"
  fi
}

export -f handle_request log
export LOGFILE UNBAN_SECRET

# ── socat loop ─────────────────────────────────────────────────
exec socat TCP-LISTEN:"$PORT",reuseaddr,fork \
  SYSTEM:'bash -c handle_request'
