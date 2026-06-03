# Security Monitor – VPS Telepítési Útmutató

## 1. Fájlok másolása a VPS-re

```bash
scp Scripts/security/*.sh Scripts/security/config.env root@YOUR_VPS_IP:/tmp/security-setup/
```

## 2. Könyvtár létrehozása és konfiguráció

```bash
mkdir -p /etc/security-monitor /var/log/security-monitor

cp /tmp/security-setup/config.env /etc/security-monitor/config.env
# SZERKESZD a config.env-t a valódi értékekkel!
nano /etc/security-monitor/config.env

chmod 600 /etc/security-monitor/config.env
```

## 3. SSH Monitor (minden belépés figyelése)

```bash
cp /tmp/security-setup/ssh-login-monitor.sh /etc/ssh/sshrc
chmod 755 /etc/ssh/sshrc
```

## 4. Fail2Ban Action

```bash
cp /tmp/security-setup/fail2ban-action.sh /etc/fail2ban/action.d/supabase-alert.sh
chmod +x /etc/fail2ban/action.d/supabase-alert.sh

# Hozd létre a .conf fájlt:
cat > /etc/fail2ban/action.d/supabase-alert.conf << 'EOF'
[Definition]
actionban   = /etc/fail2ban/action.d/supabase-alert.sh ban   <ip> <name>
actionunban = /etc/fail2ban/action.d/supabase-alert.sh unban <ip> <name>
EOF

# Adj hozzá a jail-hez (pl. /etc/fail2ban/jail.local):
# [sshd]
# action = %(action_mw)s
#          supabase-alert[name=%(name)s]
```

## 5. Unban Listener (ha admin UI-ból akarsz IP-t feloldani)

```bash
apt-get install -y socat

cp /tmp/security-setup/vps-unban-listener.sh /etc/security-monitor/
chmod +x /etc/security-monitor/vps-unban-listener.sh

cp /tmp/security-setup/unban-listener.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now unban-listener

# Firewall: CSAK Supabase IP-knek engedélyezd a 9090-es portot!
ufw allow from 52.44.28.28 to any port 9090  # Supabase AWS us-east-1
# (Ellenőrizd a Supabase aktuális IP-it a docs-ban)
```

## 6. Teszt

```bash
# Kézi teszt curl-lel:
source /etc/security-monitor/config.env
curl -X POST "$SECURITY_ALERT_URL" \
  -H "Authorization: Bearer $SECURITY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "test",
    "event_type": "brute_force",
    "ip_address": "1.2.3.4",
    "description": "Teszt riasztás"
  }'
```
