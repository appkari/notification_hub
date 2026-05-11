#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

FLAVOR=${1:-""}

echo -e "${BLUE}🐦 Notification Hub — Shorebird Patch Script${NC}"
echo "================================================"

# Prompt for flavor if not provided
if [ -z "$FLAVOR" ]; then
  echo ""
  echo "Select flavor:"
  echo "  1) development  — dev app ID"
  echo "  2) production   — production app ID"
  echo ""
  read -p "Enter flavor (development/production): " FLAVOR
fi

if [[ "$FLAVOR" != "development" && "$FLAVOR" != "production" ]]; then
  echo -e "${RED}❌ Invalid flavor. Use 'development' or 'production'${NC}"
  exit 1
fi

# Read full version from pubspec.yaml (e.g. "1.3.4+13")
FULL_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
echo ""
echo -e "Flavor          : ${YELLOW}$FLAVOR${NC}"
echo -e "Release version : ${YELLOW}$FULL_VERSION${NC}"
echo ""

echo "Choose action:"
echo "  1) patch  — quick Dart-only update (incremental)"
echo "  2) release — new baseline (native changes, Flutter upgrade, etc.)"
echo ""
read -p "Action (patch/release): " ACTION

if [[ "$ACTION" != "patch" && "$ACTION" != "release" ]]; then
  echo -e "${RED}❌ Invalid action. Use 'patch' or 'release'${NC}"
  exit 1
fi

echo ""
read -p "Proceed with shorebird $ACTION? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo -e "${RED}❌ Cancelled${NC}"
  exit 1
fi

echo ""
if [ "$ACTION" == "patch" ]; then
  echo -e "${BLUE}Patching release $FULL_VERSION ($FLAVOR)...${NC}"
  shorebird patch android --flavor "$FLAVOR" --release-version="$FULL_VERSION"
else
  echo -e "${BLUE}Creating new release ($FLAVOR)...${NC}"
  shorebird release android --flavor "$FLAVOR"
fi

echo ""
echo -e "${GREEN}✅ Done!${NC}"
