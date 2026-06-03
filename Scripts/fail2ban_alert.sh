#!/bin/bash
# =============================================================
# fail2ban_alert.sh – Fail2Ban akció script
#
# Telepítés:
#   1. Másold be: /etc/fail2ban/action.d/skeleton-alert.conf
#   2. A jail konfigurációban add hozzá: action = skeleton-alert
#
# Szükséges env változók /etc/fail2ban/skeleton.env-ben:
#   SKELETON_API_URL=https://your-domain.com/functions/v1/security-alert
#   SKELETON_API_KEY=your_bearer_token_from_app_settings
# =============================================================

set -euo pipefail

# ── Konfig betöltése ──────────────────────────────────────────
ENV_FILE="/etc/fail2ban/skeleton.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

API_URL="${SKELETON_API_URL:-}"
API_KEY="${SKELETON_API_KEY:-}"

if [[ -z "$API_URL" || -z "$API_KEY" ]]; then
  echo "[skeleton-alert] ERROR: SKELETON_API_URL or SKELETON_API_KEY not set in $ENV_FILE" >&2
  exit 1
fi

# ── Paraméterek (Fail2Ban action placeholders) ────────────────
# <ip>       → bántott IP cím
# <name>     → jail neve (pl. sshd)
# <failures> → sikertelen próbálkozások száma
ACTION="${1:-banned}"   # banned | unbanned
IP="${2:-}"
JAIL="${3:-unknown}"
FAILURES="${4:-0}"

if [[ -z "$IP" ]]; then
  echo "[skeleton-alert] ERROR: IP address is required" >&2
  exit 1
fi

# ── Event type meghatározása ──────────────────────────────────
if [[ "$ACTION" == "unban" || "$ACTION" == "unbanned" ]]; then
  EVENT_TYPE="unbanned"
  DESCRIPTION="Fail2Ban feloldotta az IP tiltást. Jail: $JAIL"
else
  EVENT_TYPE="banned"
  DESCRIPTION="Fail2Ban kitiltott IP: $IP után $FAILURES sikertelen kísérlet. Jail: $JAIL"
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── JSON payload ──────────────────────────────────────────────
PAYLOAD=$(cat <<EOF
{
  "timestamp":   "$TIMESTAMP",
  "source":      "fail2ban",
  "event_type":  "$EVENT_TYPE",
  "ip_address":  "$IP",
  "description": "$DESCRIPTION",
  "metadata": {
    "jail":     "$JAIL",
    "failures": $FAILURES,
    "action":   "$ACTION"
  }
}
EOF
)

# ── API hívás ─────────────────────────────────────────────────
HTTP_STATUS=$(curl -s -o /tmp/skeleton_alert_resp.json -w "%{http_code}" \
  -X POST "$API_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --max-time 10 \
  --retry 2 \
  --retry-delay 2)

if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "201" ]]; then
  echo "[skeleton-alert] OK: $EVENT_TYPE logged for $IP (HTTP $HTTP_STATUS)"
else
  echo "[skeleton-alert] WARN: API returned HTTP $HTTP_STATUS for $IP" >&2
  cat /tmp/skeleton_alert_resp.json >&2
fi

exit 0
