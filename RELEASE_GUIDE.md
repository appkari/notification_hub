# Release Guide

This app uses a two-tier release strategy:

## 1. Base Release (APK + Play Store) - GitHub Actions

For major releases, updates to native code, or new app store submissions.

### Setup (One-time)

1. **Generate/Get Signing Keystore**
   - If you don't have one: `keytool -genkey -v -keystore notification-hub-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias notification-hub`
   - Store this file safely (not in git)

2. **Create GitHub Secrets**
   - Go to: `Settings > Secrets and variables > Actions > New repository secret`
   - Add these secrets:

   **KEYSTORE_PROPERTIES** (base64 encoded content of `android/key.properties`)
   ```properties
   storeFile=key.jks
   storePassword=YOUR_PASSWORD
   keyAlias=notification-hub
   keyPassword=YOUR_PASSWORD
   ```
   
   To create the base64 string:
   ```bash
   cat android/key.properties | base64
   ```
   
   **SIGNING_KEYSTORE** (base64 encoded keystore file)
   ```bash
   cat notification-hub-release.jks | base64
   ```
   
   **PLAY_STORE_SERVICE_ACCOUNT** (base64 encoded Play Store key)
   ```bash
   cat ~/Downloads/play-store-service-account.json | base64
   ```

### Creating a Release

1. **Tag your release using the helper script (recommended):**
   ```bash
   # For a dev release (any branch):
   ./scripts/release.sh dev

   # For a prod release (must be on main):
   ./scripts/release.sh prod
   ```

   Or create the tag manually:
   ```bash
   # Dev release:
   git tag dev@1.0.2
   git push origin dev@1.0.2

   # Prod release (from main):
   git tag prod@1.0.2
   git push origin prod@1.0.2
   ```

2. **GitHub Actions will automatically:**
   - Build the APK & AAB (App Bundle)
   - Deploy to Play Store internal testing (prod tags only)
   - Create a GitHub Release with the APK

3. **Play Store track:**
   - Prod releases are automatically uploaded to the **internal testing** track.
   - To promote to a wider track (alpha, beta, production), use the Play Console directly after the internal release is verified.

---

## 2. Code Push Release (Shorebird) - Instant Updates

For quick bug fixes and feature updates without app store review.

### Setup (One-time)

1. **Create Shorebird account** at https://console.shorebird.dev
2. **Link your app** (already done, app_id in `shorebird.yaml`)
3. **Get Firebase token**:
   ```bash
   shorebird auth:github
   ```
4. **Add GitHub Secret**:
   - Go to: `Settings > Secrets and variables > Actions > New repository secret`
   - Add `FIREBASE_TOKEN` with your token from Shorebird

### Publishing a Code Update

**Option A: From your local machine (fastest)**
```bash
flutter pub get
shorebird release android
```

This will:
- Build the update patch
- Upload to Shorebird
- Users get the update automatically on next app launch

**Option B: Via GitHub Actions (recommended for teams)**
1. Go to `Actions > Shorebird Code Push Release > Run workflow`
2. Select environment and click "Run workflow"
3. Shorebird will release the update automatically

---

## Release Workflow Examples

### Scenario 1: Quick Bug Fix
```bash
# Make code changes
git add .
git commit -m "fix: crash on notification click"
shorebird release android
# Users get update in ~5 minutes
```

### Scenario 2: New Version with Native Changes
```bash
# Update version in pubspec.yaml
# Make code changes
git add .
git commit -m "feat: new dashboard"
./scripts/release.sh prod  # Bumps version, tags prod@1.1.0, pushes
# GitHub Actions builds APK → Release created
# Users download new version from app store/GitHub
```

### Scenario 3: Multiple Releases
```bash
# Hotfix #1
git commit -m "fix: notification bug"
shorebird release android  # Users get update in 5 min

# Hotfix #2
git commit -m "fix: crash in settings"
shorebird release android  # Users get second update

# When ready for major release
./scripts/release.sh prod  # Bumps version, tags prod@1.1.0, and pushes
```

---

## FAQ

**Q: When should I use GitHub Actions vs Shorebird?**
- Use **GitHub Actions** for: Major versions, native code changes, app store uploads
- Use **Shorebird** for: Dart/Flutter code fixes, quick patches, emergency hotfixes

**Q: Can I release before I tag?**
- Yes! Shorebird releases are independent of GitHub tags
- Use Shorebird for patches, then tag a release when you're ready for the app store

**Q: How do I rollback a Shorebird release?**
```bash
shorebird release list
shorebird release rollback v1.0.0 1  # Rollback to previous patch
```

**Q: Do I need to update build number manually?**
- For APK releases: Update version in `pubspec.yaml` (e.g., `1.0.1+2` → `1.0.2+3`)
- For code push: No build number needed, Shorebird handles it automatically

**Q: How much does this cost?**
- **GitHub Actions**: Free (2,000 minutes/month for private repos)
- **Shorebird**: Free tier for up to 1M MAU
- **Total**: $0 for most apps
