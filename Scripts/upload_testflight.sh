#!/bin/bash
# TestFlight feltöltés – Admin és Kliens app
# Használat: ./upload_testflight.sh [admin|client|all]
#
# Előfeltételek:
#   1. gem install fastlane
#   2. Töltsd ki az FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD értéket a .env-ben
#      (https://appleid.apple.com → Security → App-Specific Passwords)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$ROOT_DIR/.env"

# .env betöltése
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)
else
  echo "❌ Nem található: $ENV_FILE"
  exit 1
fi

TARGET="${1:-all}"

upload_admin() {
  echo "🚀 Admin app feltöltése TestFlightba..."
  cd "$ROOT_DIR/Flutter/admin"
  fastlane beta
  echo "✅ Admin app feltöltve!"
}

upload_client() {
  echo "🚀 Kliens app feltöltése TestFlightba..."
  cd "$ROOT_DIR/Flutter/client"
  fastlane beta
  echo "✅ Kliens app feltöltve!"
}

case "$TARGET" in
  admin)  upload_admin ;;
  client) upload_client ;;
  all)
    upload_admin
    upload_client
    ;;
  *)
    echo "Használat: $0 [admin|client|all]"
    exit 1
    ;;
esac

echo "🎉 TestFlight feltöltés kész!"
