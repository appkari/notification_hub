#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Notification Hub Release Script${NC}"
echo "======================================"
echo ""

# Get current version
CURRENT_VERSION=$(grep "version:" pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
echo -e "Current version: ${YELLOW}$CURRENT_VERSION${NC}"
echo ""

# Prompt for version
read -p "Enter new version (e.g., 1.0.2): " VERSION

if [ -z "$VERSION" ]; then
  echo -e "${RED}❌ Version cannot be empty${NC}"
  exit 1
fi

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}❌ Invalid version format. Use: major.minor.patch${NC}"
  exit 1
fi

BUILD_NUMBER=$((${CURRENT_VERSION##*.} + 1))
NEW_VERSION="$VERSION+$BUILD_NUMBER"

echo -e "${GREEN}New version will be: $NEW_VERSION${NC}"
echo ""

# Confirm changes
read -p "Proceed with release? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}❌ Release cancelled${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}Step 1: Updating version in pubspec.yaml${NC}"
sed -i '' "s/version: .*/version: $NEW_VERSION/" pubspec.yaml
echo -e "${GREEN}✅ Version updated to $NEW_VERSION${NC}"

echo ""
echo -e "${BLUE}Step 2: Committing changes${NC}"
git add pubspec.yaml
git commit -m "chore: bump to $VERSION" || echo -e "${YELLOW}⚠️  No changes to commit${NC}"
echo -e "${GREEN}✅ Changes committed${NC}"

echo ""
echo -e "${BLUE}Step 3: Creating git tag v$VERSION${NC}"
git tag "v$VERSION" || echo -e "${YELLOW}⚠️  Tag already exists${NC}"
echo -e "${GREEN}✅ Tag created: v$VERSION${NC}"

echo ""
echo -e "${BLUE}Step 4: Pushing to GitHub${NC}"
git push origin fixes "v$VERSION"
echo -e "${GREEN}✅ Tag pushed to GitHub${NC}"

echo ""
echo -e "${GREEN}✅ Release triggered!${NC}"
echo ""
echo -e "${YELLOW}📊 Track progress:${NC}"
echo "   https://github.com/appkari/notification_hub/actions"
echo ""
echo -e "${YELLOW}📱 Play Store deployment:${NC}"
echo "   - Internal testing: Automatic (default)"
echo "   - For other tracks: Go to Actions > Run workflow > Select track"
echo ""
