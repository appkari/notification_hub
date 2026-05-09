#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ENV=${1:-""}

echo -e "${BLUE}🚀 Notification Hub Release Script${NC}"
echo "======================================"

# Prompt for environment if not provided
if [ -z "$ENV" ]; then
  echo ""
  echo "Select environment:"
  echo "  1) dev  — any branch, development flavor, GitHub artifact only"
  echo "  2) prod — main branch only, production flavor, deploys to Play Store"
  echo ""
  read -p "Enter environment (dev/prod): " ENV
fi

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo -e "${RED}❌ Invalid environment. Use 'dev' or 'prod'${NC}"
  exit 1
fi

# Prod must run from main
if [ "$ENV" == "prod" ]; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

  if [ "$CURRENT_BRANCH" != "main" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Prod release requires main branch (currently on: $CURRENT_BRANCH)${NC}"
    read -p "Forward-merge dev → main and switch? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${RED}❌ Release cancelled${NC}"
      exit 1
    fi

    echo ""
    echo -e "${BLUE}Merging dev → main...${NC}"
    git fetch origin
    git checkout main
    git merge --no-edit origin/dev
    echo -e "${GREEN}✅ Merged dev → main${NC}"
  fi
fi

# Get current version
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
CURRENT_BUILD=$(grep "^version:" pubspec.yaml | awk '{print $2}' | cut -d'+' -f2)
echo ""
echo -e "Current version : ${YELLOW}$CURRENT_VERSION+$CURRENT_BUILD${NC}"
echo -e "Environment     : ${YELLOW}$ENV${NC}"
echo ""

read -p "Enter new version (e.g., 1.0.2) or press enter to keep $CURRENT_VERSION: " VERSION
VERSION=${VERSION:-$CURRENT_VERSION}

if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}❌ Invalid version format. Use: major.minor.patch${NC}"
  exit 1
fi

NEW_BUILD=$((CURRENT_BUILD + 1))
TAG="$ENV@$VERSION"

echo ""
echo -e "New version : ${GREEN}$VERSION+$NEW_BUILD${NC}"
echo -e "Tag         : ${GREEN}$TAG${NC}"
echo ""

read -p "Proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${RED}❌ Release cancelled${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}Step 1: Updating pubspec.yaml${NC}"
sed -i '' "s/^version: .*/version: $VERSION+$NEW_BUILD/" pubspec.yaml
echo -e "${GREEN}✅ Version → $VERSION+$NEW_BUILD${NC}"

echo ""
echo -e "${BLUE}Step 2: Committing${NC}"
git add pubspec.yaml
git commit -m "chore: bump to $VERSION ($ENV)" || echo -e "${YELLOW}⚠️  Nothing to commit${NC}"
echo -e "${GREEN}✅ Committed${NC}"

echo ""
echo -e "${BLUE}Step 3: Tagging as $TAG${NC}"
git tag "$TAG"
echo -e "${GREEN}✅ Tagged: $TAG${NC}"

echo ""
echo -e "${BLUE}Step 4: Pushing${NC}"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$BRANCH" "$TAG"
echo -e "${GREEN}✅ Pushed branch + tag${NC}"

echo ""
echo -e "${GREEN}✅ Release triggered!${NC}"
echo ""
if [ "$ENV" == "prod" ]; then
  echo -e "${YELLOW}📱 Play Store:${NC} Uploading to internal testing..."
else
  echo -e "${YELLOW}📦 Dev APK:${NC} Will be available as GitHub Release artifact"
fi
echo ""
echo -e "${YELLOW}📊 Monitor:${NC} https://github.com/appkari/notification_hub/actions"
echo ""
