# App Exclusion and Codebase Review

## Executive Summary

- **App exclusion verdict:** **Flawed**
- **Overall codebase state:** Functional and analyzable, but several correctness and maintainability issues should be addressed.
- **Validation run:** `flutter analyze` passed, `flutter test` passed.

## App Exclusion Review

## Expected Flow

1. Android receives notifications in `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`.
2. Notifications are forwarded to Flutter through the `notification_capture` `MethodChannel`.
3. `lib/services/notification_service.dart` filters excluded apps and channels in `_handleMethodCall()` before adding notifications to the stream.
4. `lib/providers/notification_provider.dart` listens to that stream, updates in-memory state, and persists notifications in Drift.
5. UI exclusion actions are triggered from:
   - `lib/screens/app_management_screen.dart`
   - `lib/screens/settings_screen.dart`
   - `lib/widgets/home/app_notification_card.dart`

## What Works

- Excluded apps are persisted in `SharedPreferences` via `NotificationService`.
- Incoming notifications are filtered against `_excludedApps` and `_excludedChannels` in `NotificationService._handleMethodCall()`.
- `NotificationProvider.excludeApp()` removes existing matching notifications from memory, archives them to history, removes them from the system tray, and deletes them from the database.
- `NotificationProvider.loadNotifications()` also re-filters DB-loaded notifications against the exclusion list.

## Why It Is Flawed

### 1. Mutable exclusion state escapes the service

**Files:**
- `lib/services/notification_service.dart`
- `lib/screens/app_management_screen.dart`

`NotificationService.getExcludedApps()` returns the service-owned `Set<String>` directly. `AppManagementScreen` stores that set in `_excludedApps` and mutates it locally before calling `provider.excludeApp()` / `provider.includeApp()`.

That means this flow can happen:

1. UI gets the same `Set` instance owned by `NotificationService`
2. UI mutates it with `_excludedApps.add(...)` or `_excludedApps.remove(...)`
3. Service method later calls `_excludedApps.add(...)` or `_excludedApps.remove(...)`
4. The add/remove may return `false`, so persistence can silently skip

This makes exclusion persistence fragile and can cause real mismatches between UI state and saved state.

### 2. Notification identity is not stable enough

**Files:**
- `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`
- `lib/models/notification_model.dart`
- `lib/database/app_database.dart`

The app uses `sbn.id` as the notification `id` in the forwarded model. That value is not globally unique across all apps. Two apps can reuse the same integer ID, which can cause:

- wrong in-place updates
- wrong removals
- database overwrites
- cross-app collisions in active notification state

The app should use the Android notification `key` as the stable primary identity end-to-end.

### 3. Debounced posted notifications can outlive removals

**File:** `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`

Posted notifications are debounced through `pendingRunnables` and `pendingPostedNotifications`. If a notification is removed before the delayed runnable fires, the pending posted event is not fully canceled first. That can produce a stale “new” notification after removal.

### 4. Undo behavior is inconsistent across screens

**Files:**
- `lib/screens/app_management_screen.dart`
- `lib/widgets/home/app_notification_card.dart`

`AppManagementScreen` exclusion undo restores removed notifications. `AppNotificationCard` undo only calls `includeApp(packageName)` and does **not** restore removed notifications. Same feature, different behavior.

### 5. Native side does not filter exclusions

**Files:**
- `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`
- `lib/services/notification_service.dart`

Filtering only happens on the Flutter side. That is acceptable functionally, but it means excluded notifications still cross the native bridge, get processed, and only then are dropped. It is less efficient and makes ordering issues harder to reason about.

## Conclusion on App Exclusion

The feature is **partially implemented but not reliable enough to call “working fine.”** The filtering intent is correct, but state ownership and notification identity problems make the system vulnerable to silent persistence bugs and incorrect notification reconciliation.

## Recommended Fixes for App Exclusion

1. Return defensive copies from:
   - `NotificationService.getExcludedApps()`
   - `NotificationService.getExcludedChannelKeys()`
2. Ensure UI never mutates service-owned sets directly.
3. Promote Android `sbn.key` to the primary notification identity in model, provider, and database.
4. Cancel queued posted-notification debounce entries when removals arrive.
5. Make undo behavior consistent across all exclusion entry points.

---

## Codebase Improvement Review

## High Priority

### 1. Fix exclusion state ownership

**Files:**
- `lib/services/notification_service.dart`
- `lib/screens/app_management_screen.dart`
- `lib/screens/settings_screen.dart`

This is the most important correctness fix because it affects persisted user settings.

### 2. Use a stable unique notification identity everywhere

**Files:**
- `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`
- `lib/models/notification_model.dart`
- `lib/database/app_database.dart`
- `lib/providers/notification_provider.dart`

Using `sbn.key` instead of `sbn.id` would make updates, removals, and storage much safer.

### 3. Add focused exclusion and lifecycle tests

**Files:** `test/`

Current tests pass, but there is no meaningful coverage for:

- app exclusion persistence
- exclusion undo behavior
- channel exclusion
- provider behavior when excluded notifications already exist
- posted/removed ordering edge cases

## Medium Priority

### 4. Reduce service/UI shared mutable state patterns

**Files:**
- `lib/services/notification_service.dart`
- `lib/providers/notification_provider.dart`
- `lib/screens/app_management_screen.dart`

Several flows rely on mutable collections owned by long-lived singletons. Prefer immutable snapshots across service boundaries.

### 5. Tighten native notification queue cleanup

**File:** `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`

The native service keeps multiple maps for pending intents and debounce state. Cleanup exists in some paths, but this area is complex enough to deserve explicit lifecycle cleanup and tests.

### 6. Normalize exclusion UX behavior

**Files:**
- `lib/screens/app_management_screen.dart`
- `lib/widgets/home/app_notification_card.dart`
- `lib/screens/settings_screen.dart`

The same user action should have the same side effects and undo semantics no matter where it is triggered.

### 7. Strengthen provider error boundaries

**File:** `lib/providers/notification_provider.dart`

The provider does a lot: stream ingestion, persistence, history management, tray cleanup, summary updates, pagination, and restore flows. Splitting responsibilities or at least isolating failure handling would make this easier to maintain.

## Lower Priority

### 8. Review root-level documentation drift

**File:** `CODEBASE_REVIEW.md`

There is already a review file in the repo. If it is still used, it should be updated or replaced to avoid duplicated, drifting audit docs.

### 9. Continue improving storage/query efficiency

**File:** `lib/database/app_database.dart`

The database already has timestamp/package indexes added in schema version 5. Future improvements should focus on query patterns and migration coverage, not just adding more indexes blindly.

### 10. Expand integration-style testing for native bridge assumptions

**Files:**
- `android/app/src/main/kotlin/in/appkari/notihub/MainActivity.kt`
- `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`
- `test/`

The most failure-prone paths are bridge/lifecycle paths, but current coverage is mostly Dart-side unit/widget tests.

---

## Evidence Collected

### Static Inspection

- `lib/services/notification_service.dart`
- `lib/providers/notification_provider.dart`
- `lib/screens/app_management_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/widgets/home/app_notification_card.dart`
- `android/app/src/main/kotlin/in/appkari/notihub/NotiHubNotificationService.kt`
- `android/app/src/main/kotlin/in/appkari/notihub/MainActivity.kt`
- `lib/database/app_database.dart`
- `lib/services/icon_cache_service.dart`
- `test/notification_provider_test.dart`

### Automated Checks

- `flutter analyze` ✅
- `flutter test` ✅
- Dart LSP diagnostics for `lib/` ✅

## Recommended Next Steps

1. Fix exclusion-state mutability first.
2. Migrate notification identity from `id` to stable `key`.
3. Add tests for exclusion persistence, undo flows, and remove/post race conditions.
4. Unify exclusion behavior across all UI entry points.
