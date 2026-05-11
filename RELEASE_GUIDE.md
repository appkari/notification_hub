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
    > ⚠️ **IMPORTANT**: The `keyAlias` value **must match** the alias used when creating the keystore with `keytool`. A mismatch will cause the CI build to fail with `KeytoolException: No key with alias 'X' found in keystore`.
   
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
    > ⚠️ After adding the secret, **grant the service account access in Google Play Console**: Go to Play Console → Users & Permissions → Invite new user, add the service account email (from `client_email` in the JSON), and assign at minimum a **"Release"** permission. Without this, CI will fail with `Google Api Error: The caller does not have permission`.

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

## 2. Code Push (Shorebird) — Instant Updates

For quick bug fixes and feature updates without app store review.

> **Important**: This project uses **flavors** (`development` / `production`). All Shorebird commands must include the `--flavor` flag.

### Setup (One-time)

1. **Create Shorebird account** at https://console.shorebird.dev
2. **Install Shorebird CLI**:
   ```bash
   curl --proto '=https' --tlsv1.2 -LsSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | sh
   ```
3. **Log in**:
   ```bash
   shorebird login
   ```
4. **Init the project** (links this app to your account):
   ```bash
   shorebird init --force
   ```
   This updates `shorebird.yaml` with app IDs tied to your account.

### Publishing a Code Update

**Option A: From your local machine (recommended)**

Use the helper script (reads the current version from `pubspec.yaml` automatically):

```bash
# Quick Dart-only fix (incremental patch)
./scripts/patch.sh production

# New baseline (needed after native changes, Flutter upgrades, etc.)
./scripts/patch.sh production  # then choose "release"
```

**Option B: Manual commands**

```bash
# Incremental patch (Dart-only changes)
shorebird patch android --flavor production --release-version=1.3.4+13

# New baseline release
shorebird release android --flavor production
```

> **Note**: The `--release-version` must be the **full version string** from `pubspec.yaml` (e.g. `1.3.4+13`). Use `shorebird releases list --flavor production` to see existing releases.

---

## Release Workflow Examples

### Scenario 1: Quick Bug Fix (Dart-only)
```bash
# Make code changes
git add .
git commit -m "fix: crash on notification click"

# Push as Shorebird patch (no app store, no APK)
./scripts/patch.sh production
# Choose "patch" — users get the fix in ~5 minutes
```

### Scenario 2: New Version with Native Changes
```bash
# Update version in pubspec.yaml
# Make code changes
git add .
git commit -m "feat: new dashboard"
./scripts/release.sh prod  # Bumps version, tags prod@1.2.0, pushes
# GitHub Actions builds APK → Release created

# Then create new Shorebird baseline
./scripts/patch.sh production
# Choose "release" — must create a new baseline after native changes
```

### Scenario 3: Multiple Patches
```bash
# Hotfix #1
git commit -m "fix: notification bug"
./scripts/patch.sh production  # Choose "patch" — users get fix in 5 min

# Hotfix #2
git commit -m "fix: crash in settings"
./scripts/patch.sh production  # Choose "patch" — second incremental update

# When ready for major release
./scripts/release.sh prod  # Bumps version, tags prod@1.1.0, pushes
```

---

## FAQ

**Q: When should I use GitHub Actions vs Shorebird?**
- Use **GitHub Actions** (`release.sh`) for: Major versions, native code changes, app store uploads
- Use **Shorebird** (`patch.sh`) for: Dart/Flutter code fixes, quick patches, emergency hotfixes

**Q: Can I release before I tag?**
- Yes! Shorebird releases are independent of GitHub tags
- Use Shorebird for patches, then tag a release when you're ready for the app store

**Q: How do I rollback a Shorebird release?**
```bash
shorebird releases list --flavor production
shorebird release rollback 1.3.4+13 1  # Rollback to previous patch on that version
```

**Q: Do I need to update build number manually?**
- For APK releases: Update version in `pubspec.yaml` (e.g., `1.0.1+2` → `1.0.2+3`)
- For code push: No build number needed, Shorebird handles it automatically

**Q: How much does this cost?**
- **GitHub Actions**: Free (2,000 minutes/month for private repos)
- **Shorebird**: Free tier for up to 1M MAU
- **Total**: $0 for most apps
