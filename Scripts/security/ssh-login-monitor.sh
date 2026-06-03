#!/usr/bin/env bash
# ============================================================
# SSH Login Monitor – /etc/ssh/sshrc  (vagy PAM exec)
# ============================================================
# Ez a script akkor fut le, amikor egy felhasználó sikeresen
# SSH-val bejelentkezik. A $SSH_CONNECTION env változóból
# kinyeri a kliens IP-t, majd riasztást küld.
#
# TELEPÍTÉS:
#   Módszer A – sshrc (minden userre):
#     cp ssh-login-monitor.sh /etc/ssh/sshrc
#     chmod 755 /etc/ssh/sshrc
#
#   Módszer B – PAM (root belépésre külön figyelés):
#     echo "session optional pam_exec.so /etc/security-monitor/ssh-login-monitor.sh" \
#       >> /etc/pam.d/sshd
#     cp ssh-login-monitor.sh /etc/security-monitor/ssh-login-monitor.sh
#     chmod 755 /etc/security-monitor/ssh-login-monitor.sh
# ============================================================

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
  # Csendesen kilép ha nincs konfigurálva (ne törje az SSH session-t)
  exit 0
fi

# ── SSH adatok kinyerése ───────────────────────────────────────
# $SSH_CONNECTION: "kliens_ip kliens_port szerver_ip szerver_port"
CLIENT_IP=""
if [[ -n "${SSH_CONNECTION:-}" ]]; then
  CLIENT_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
fi

# PAM módban a PAM_RHOST tartalmazza a kliens IP-t
if [[ -z "$CLIENT_IP" && -n "${PAM_RHOST:-}" ]]; then
  CLIENT_IP="$PAM_RHOST"
fi

# Ha egyik sem elérhető, unknown
CLIENT_IP="${CLIENT_IP:-unknown}"

LOGIN_USER="${USER:-${PAM_USER:-unknown}}"
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Root belépés különösen veszélyes
DESCRIPTION="Sikeres SSH belépés: $LOGIN_USER @ $HOSTNAME (kliens: $CLIENT_IP)"

PAYLOAD=$(cat <<EOF
{
  "timestamp":   "$TIMESTAMP",
  "source":      "ssh_monitor",
  "event_type":  "successful_ssh_login",
  "ip_address":  "$CLIENT_IP",
  "description": "$DESCRIPTION",
  "metadata": {
    "username": "$LOGIN_USER",
    "hostname": "$HOSTNAME",
    "is_root":  $([ "$LOGIN_USER" = "root" ] && echo "true" || echo "false")
  }
}
EOF
)

# ── Webhook hívás (háttérben, hogy ne lassítsa a logint) ───────
curl \
  --silent \
  --output /dev/null \
  --max-time 8 \
  --retry 2 \
  -X POST \
  -H "Authorization: Bearer $SECURITY_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$SECURITY_ALERT_URL" &

# Kilépés 0-val hogy ne törje a login-t
exit 0
