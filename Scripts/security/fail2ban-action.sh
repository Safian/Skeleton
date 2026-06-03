#!/usr/bin/env bash
# ============================================================
# Fail2Ban Action Script – Security Alert Webhook
# ============================================================
# Telepítés:
#   1. cp fail2ban-action.sh /etc/fail2ban/action.d/supabase-alert.sh
#   2. chmod +x /etc/fail2ban/action.d/supabase-alert.sh
#   3. Hozd létre a /etc/fail2ban/action.d/supabase-alert.conf fájlt (lásd lentebb)
#   4. A jail-ed [action] szekciójába add hozzá: action = supabase-alert[name=%(__name__)s]
# ============================================================
#
# /etc/fail2ban/action.d/supabase-alert.conf tartalma:
# ---
# [Definition]
# actionban   = /etc/fail2ban/action.d/supabase-alert.sh ban   "<ip>"   "<name>"
# actionunban = /etc/fail2ban/action.d/supabase-alert.sh unban "<ip>"   "<name>"
# ---

set -euo pipefail

# ── Config betöltés ────────────────────────────────────────────
CONFIG_FILE="/etc/security-monitor/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

SECURITY_ALERT_URL="${SECURITY_ALERT_URL:-}"
SECURITY_API_KEY="${SECURITY_API_KEY:-}"

if [[ -z "$SECURITY_ALERT_URL" || -z "$SECURITY_API_KEY" ]]; then
  echo "[supabase-alert] ERROR: SECURITY_ALERT_URL vagy SECURITY_API_KEY nincs beállítva." >&2
  exit 1
fi

# ── Paraméterek ────────────────────────────────────────────────
ACTION="${1:-}"   # 'ban' vagy 'unban'
IP="${2:-}"
JAIL="${3:-sshd}"

if [[ -z "$ACTION" || -z "$IP" ]]; then
  echo "[supabase-alert] Használat: $0 <ban|unban> <ip> [jail]" >&2
  exit 1
fi

# ── Event típus meghatározása ──────────────────────────────────
if [[ "$ACTION" == "ban" ]]; then
  EVENT_TYPE="brute_force"
  DESCRIPTION="Fail2Ban kitiltotta: $IP (jail: $JAIL)"
else
  EVENT_TYPE="unbanned"
  DESCRIPTION="Fail2Ban feloldotta: $IP (jail: $JAIL)"
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

# ── JSON payload ───────────────────────────────────────────────
PAYLOAD=$(cat <<EOF
{
  "timestamp":   "$TIMESTAMP",
  "source":      "fail2ban",
  "event_type":  "$EVENT_TYPE",
  "ip_address":  "$IP",
  "description": "$DESCRIPTION",
  "metadata": {
    "jail":     "$JAIL",
    "action":   "$ACTION",
    "hostname": "$HOSTNAME"
  }
}
EOF
)

# ── Webhook hívás ──────────────────────────────────────────────
HTTP_CODE=$(curl \
  --silent \
  --output /dev/null \
  --write-out "%{http_code}" \
  --max-time 10 \
  --retry 3 \
  --retry-delay 2 \
  -X POST \
  -H "Authorization: Bearer $SECURITY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$SECURITY_ALERT_URL"
)

if [[ "$HTTP_CODE" == "201" ]]; then
  echo "[supabase-alert] OK ($ACTION $IP) – HTTP $HTTP_CODE"
else
  echo "[supabase-alert] WARN: HTTP $HTTP_CODE ($ACTION $IP)" >&2
  exit 1
fi
