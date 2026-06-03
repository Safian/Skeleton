#!/bin/zsh
# ============================================================
# Skeleton Admin – futtatás weben és/vagy iOS simulátoron
#
# Használat:
#   ./run_admin.sh           -> web + iOS
#   ./run_admin.sh web       -> csak Chrome (port 3001)
#   ./run_admin.sh ios       -> csak iOS Simulator
#
# Admin belépéshez: UPDATE user_profiles SET role='admin'
#   WHERE email='te@email.com';
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/../Flutter/admin"
WEB_PORT=3001          # Klienssel párhuzamosan fut!
IOS_DEVICE="iPhone 17 Pro"
FLUTTER="${FLUTTER_BIN:-/Users/szabi/develop/flutter/bin/flutter}"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

echo ""
echo "${BOLD}${BLUE}============================================${NC}"
echo "${BOLD}${BLUE}   Skeleton Admin${NC}"
echo "${BOLD}${BLUE}============================================${NC}"
echo ""

# Ellenőrzések
if [ ! -x "$FLUTTER" ]; then
  echo "${RED}Flutter nem talalhato: $FLUTTER${NC}"
  echo "Allitsd be: export FLUTTER_BIN=/path/to/flutter/bin/flutter"
  exit 1
fi
if [ ! -d "$APP_DIR" ]; then
  echo "${RED}App konyvtar nem talalhato: $APP_DIR${NC}"
  exit 1
fi

# pub get ha szükséges
if [ ! -f "$APP_DIR/.dart_tool/package_config.json" ]; then
  echo "${YELLOW}flutter pub get...${NC}"
  cd "$APP_DIR" && "$FLUTTER" pub get
fi

run_web() {
  echo "${GREEN}Admin web: http://localhost:${WEB_PORT}${NC}"
  osascript -e "tell application \"Terminal\" to do script \"cd '$APP_DIR' && '$FLUTTER' run -d chrome --web-port=$WEB_PORT --web-hostname=localhost\""
}

run_ios() {
  echo "${GREEN}iOS Simulator: $IOS_DEVICE${NC}"
  open -a Simulator
  sleep 2
  xcrun simctl boot "$IOS_DEVICE" 2>/dev/null || true
  osascript -e "tell application \"Terminal\" to do script \"cd '$APP_DIR' && '$FLUTTER' run -d '$IOS_DEVICE'\""
}

case "${1:-all}" in
  web)  run_web ;;
  ios)  run_ios ;;
  all)
    run_web
    sleep 2
    run_ios
    ;;
  *)
    echo "${RED}Ismeretlen: $1${NC} – hasznalat: $0 [web|ios]"
    exit 1
    ;;
esac

echo ""
echo "${BOLD}${GREEN}Admin elindult! Hot reload: r  |  Leallitas: q${NC}"
echo "${YELLOW}Admin belépéshez role=admin szükséges a Supabase-ben!${NC}"
echo ""
