#!/bin/bash
# =============================================================
# vps_unban_listener.sh – Egyszerű HTTP listener az admin unban-hez
#
# A Supabase security-unban edge function ezt hívja meg, ha az
# admin az Admin Panelről felold egy IP-t.
# Ez a script futtatja a tényleges `fail2ban-client unban` parancsot.
#
# Függőség: netcat (nc), curl (health check)
#
# Telepítés:
#   sudo cp vps_unban_listener.sh /opt/skeleton/scripts/
#   sudo chmod +x /opt/skeleton/scripts/vps_unban_listener.sh
#   sudo cp vps_unban_listener.service /etc/systemd/system/
#   sudo systemctl enable --now vps_unban_listener
#
# Port: 9090 (belső, NE tedd ki a nyilvános internetre!)
# Nginx reverse proxy-n keresztül érhető el, ha kell.
# =============================================================

set -euo pipefail

PORT=9090
LISTEN_HOST="127.0.0.1"   # csak localhost – nginx proxyn keresztül hívja a Supabase

# ── Belső secret (egyezzen meg az app_settings.unban_webhook_url-ben lévővel) ─
UNBAN_SECRET="${UNBAN_LISTENER_SECRET:-changeme_set_in_env}"

log() { echo "[vps-unban] $(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"; }

log "Unban listener indul: $LISTEN_HOST:$PORT"

# ── HTTP kérés feldolgozó ─────────────────────────────────────
handle_request() {
  local request_body=""
  local content_length=0
  local auth_header=""
  local line

  # HTTP fejlécek olvasása
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

  # Body olvasása
  if [[ "$content_length" -gt 0 ]]; then
    request_body=$(head -c "$content_length")
  fi

  # Secret ellenőrzés
  if [[ "$auth_header" != "$UNBAN_SECRET" ]]; then
    log "WARN: Unauthorized unban request (wrong secret)"
    printf 'HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\n\r\n{"error":"unauthorized"}'
    return
  fi

  # IP cím kinyerése a JSON body-ból (minimális JSON parse)
  local ip_address jail
  ip_address=$(echo "$request_body" | grep -oP '"ip_address"\s*:\s*"\K[^"]+' || true)
  jail=$(echo "$request_body" | grep -oP '"jail"\s*:\s*"\K[^"]+' || echo "sshd")

  if [[ -z "$ip_address" ]]; then
    log "ERROR: Missing ip_address in body"
    printf 'HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\n\r\n{"error":"missing ip_address"}'
    return
  fi

  log "Unban request: IP=$ip_address, jail=$jail"

  # ── fail2ban-client unban ─────────────────────────────────────
  if command -v fail2ban-client &>/dev/null; then
    if fail2ban-client set "$jail" unbanip "$ip_address" 2>/dev/null; then
      log "OK: Unbanned $ip_address from jail $jail"
      printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"ok":true,"ip":"%s","jail":"%s"}' "$ip_address" "$jail"
    else
      log "WARN: fail2ban-client returned error for $ip_address (may not have been banned)"
      printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{"ok":true,"note":"not_in_jail","ip":"%s"}' "$ip_address"
    fi
  else
    log "WARN: fail2ban-client not found – is fail2ban installed?"
    printf 'HTTP/1.1 503 Service Unavailable\r\nContent-Type: application/json\r\n\r\n{"error":"fail2ban not available"}'
  fi
}

# ── TCP listener loop (netcat) ────────────────────────────────
while true; do
  nc -l -p "$PORT" -s "$LISTEN_HOST" -q 1 < <(handle_request) 2>/dev/null || true
  sleep 0.1
done
