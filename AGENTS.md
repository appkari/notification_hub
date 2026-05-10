# Notification Hub — AI Agent Guide

## Project Overview

Android-only Flutter app that captures, organizes, and manages notifications from all installed apps via `NotificationListenerService`. Built with Flutter 3.32, Dart SDK ^3.7.0.

**Package**: `in.appkari.notihub` (production) / `in.appkari.notihub.dev` (development)  
**Min SDK**: Android API 21+

## Critical Rules (MUST FOLLOW)

- **NEVER auto-commit or auto-push anything.** Always wait for explicit user instruction before committing code or pushing to remote. This includes creating tags, merging branches, and any git operation that reaches the remote.
- **NEVER create release tags** (`prod@*`, `dev@*`) unless the user explicitly requests it via the release script (`scripts/release.sh`).
- **NEVER modify CI/CD workflows** (`.github/workflows/`) without explicit user request.
- **NEVER modify `pubspec.yaml` version** without explicit user request.

## Architecture

### State Management
Provider pattern (`package:provider`). Key providers:
- `NotificationProvider` — notifications, capture state, app exclusion, DB operations
- `ThemeProvider` — light/dark/system theme mode
- `SubscriptionProvider` — in-app purchase premium status

### Key Flows

```
NotificationListenerService (Android)
  → MethodChannel → NotificationService (Dart singleton)
  → NotificationProvider (ChangeNotifier)
  → UI (HomeScreen → NotificationListView → AppNotificationCard)
  → Drift DB (persistence)
```

### Data Layer
- **Drift** (`package:drift`) — local SQLite DB for notifications and history
  - `app_database.dart` — schema with `Notifications` and `NotificationHistory` tables
  - `notification_store.dart` — `DriftNotificationStore` wraps DB operations
- **SharedPreferences** — settings (excluded apps/channels, history days, theme, icon cache)

### Directory Structure

```
lib/
├── main.dart / main_development.dart / main_production.dart  (entry points)
├── database/     — Drift DB schema
├── models/       — AppNotification, NotificationChannelInfo, SubscriptionModel
├── providers/    — ChangeNotifier providers
├── screens/      — Home, Settings, Dashboard, History, Detail, AppManagement, Subscription
├── services/     — NotificationService (native bridge), NotificationStore, IconCacheService, SubscriptionService
└── widgets/
    └── home/     — PermissionRequestWidget, NotificationListView, AppNotificationCard, NotificationItemWidget

android/app/src/main/kotlin/in/appkari/notihub/
├── MainActivity.kt              — MethodChannel handler (launchApp, openAppInfo, etc.)
├── NotiHubNotificationService.kt — NotificationListenerService (capture, pending intents)
└── NotiHubBootReceiver.kt       — Boot receiver
```

## Key Patterns

### Widget Design
- Pure rendering widgets (stateless, no side effects)
- Composition over inheritance
- Smart callbacks (pass functions up, don't own state in leaf widgets)
- Spacing helpers: `heightSpacer()` / `widthSpacer()` (from `widgets/integer_multiple.dart`)
- All items in TODO.md must use `- [ ]` markdown checkboxes

### Naming
- Files: `snake_case`
- Classes/types: `UpperCamelCase`
- Variables/functions: `lowerCamelCase`
- Constants: `UPPER_SNAKE_CASE`
- 2-space indentation

### Imports
- Use `package:` imports with explicit `show` members
- Ordered and trimmed

## Flavors & Build

```bash
# Development
flutter run --flavor development -t lib/main_development.dart

# Production
flutter run --flavor production -t lib/main_production.dart

# Using pnpm (sets up env.local.json)
pnpm start consumer    # development flavor
```

### Codegen & Lint
```bash
flutter pub get                          # get deps
flutter build runner                     # run build_runner
flutter analyze                          # analyze/lint
dart format .                            # format
flutter test                             # run tests
```

## Release Process (Codemagic)

Codemagic watches git tags and handles all builds + Play Store deploys.

**Creating a release (manual):**
```bash
# Dev release (any branch)
bash scripts/release.sh dev

# Prod release (must be on main)
bash scripts/release.sh prod
```

The script bumps `pubspec.yaml` version, commits, creates a tag (`prod@X.Y.Z` or `dev@X.Y.Z`), and pushes. Codemagic picks up the tag automatically.

**GitHub Actions**: The prod GH workflow (`release-prod.yml`) only runs `flutter analyze` + `flutter test` for validation. Codemagic handles all builds and deploys.

## Known Issues

- **launchApp fallback**: `MainActivity.kt` has a 3-tier fallback for opening apps: launcher intent → exported activity → app info settings page. Some deeply system-integrated apps may still fail to open — this is a platform limitation.
- **Icon cache**: SharedPreferences-based icon cache can grow unbounded. Needs LRU eviction.
- **Test coverage**: Minimal. 6 widget tests exist but many flows (settings, dashboard, subscription, native bridge) are untested.

## Project TODO

See [TODO.md](TODO.md) for the feature roadmap, bug tracker, and tech debt backlog.
