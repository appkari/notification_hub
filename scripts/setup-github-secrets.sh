#!/bin/bash
# Setup GitHub Secrets for CI/CD

set -e

echo "📦 GitHub Secrets Setup for Notification Hub"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Keystore Setup${NC}"
echo ""

if [ ! -f "android/app/key.jks" ]; then
    echo -e "${YELLOW}⚠️  Signing keystore not found${NC}"
    echo "You need to create or provide your signing keystore."
    echo ""
    echo "Option A: Create a new keystore (development/testing only)"
    echo "  keytool -genkey -v -keystore android/app/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias notification-hub"
    echo ""
    echo "Option B: Use existing keystore"
    echo "  cp /path/to/your/key.jks android/app/key.jks"
    echo ""
    read -p "Press enter after placing keystore in android/app/key.jks"
fi

if [ ! -f "android/key.properties" ]; then
    echo -e "${YELLOW}⚠️  key.properties not found${NC}"
    echo "Please create android/key.properties with:"
    echo ""
    cat << 'EOF'
storeFile=app/key.jks
storePassword=YOUR_PASSWORD
keyAlias=notification-hub
keyPassword=YOUR_PASSWORD
EOF
    echo ""
    read -p "Press enter after creating key.properties"
fi

echo ""
echo -e "${BLUE}Step 2: Encode Secrets${NC}"
echo ""

KEYSTORE_B64=$(cat android/app/key.jks | base64 | tr -d '\n')
PROPERTIES_B64=$(cat android/key.properties | base64 | tr -d '\n')

echo -e "${GREEN}✓ KEYSTORE_PROPERTIES:${NC}"
echo "$PROPERTIES_B64"
echo ""
echo -e "${GREEN}✓ SIGNING_KEYSTORE:${NC}"
echo "$KEYSTORE_B64"
echo ""

echo -e "${BLUE}Step 3: Add to GitHub${NC}"
echo ""
echo "Go to: https://github.com/sudhanshu/notification-hub/settings/secrets/actions"
echo ""
echo "Add these secrets:"
echo "  1. KEYSTORE_PROPERTIES = $(echo "$PROPERTIES_B64" | cut -c1-50)..."
echo "  2. SIGNING_KEYSTORE = $(echo "$KEYSTORE_B64" | cut -c1-50)..."
echo ""
echo "For Shorebird releases:"
echo "  3. FIREBASE_TOKEN = <token from 'shorebird auth:github'>"
echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
