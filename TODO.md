# TODO — Notification Hub

## ⚠️ Known Bug

- [ ] **[BUG] Some apps don't open on tap — toast says "could not open" but the app should be launchable**

  **Location**: `MainActivity.kt:202` and `notification_item_widget.dart:94`

  **Root cause**: `getLaunchIntentForPackage()` returns null for apps without a MAIN launcher activity. This affects system apps (Phone, Contacts, Settings provider), background/service-only apps, and some OEM pre-installed apps.

  **On the Flutter side** (`notification_item_widget.dart:70-141`): when `launchApp` returns false, the error snackbar is shown.

  **Fix options**:
  1. Fall back to `packageManager.queryIntentActivities()` with a broader Intent to find any exported activity
  2. Last resort: open app's Android Settings info page (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`)
  3. Log the failing package name for debugging

## Next Up

- [ ] **Save / Share Notification** — Long-press or action to save notification as a note, share via system share sheet, or bookmark for later reference
- [ ] **Notification Search** — Search bar at top of home screen to filter notifications by title, body, or app name

## Medium Priority

- [ ] **Favorites / Pinned Notifications** — Pin important notifications to keep them at the top of the list regardless of recency
- [ ] **Export / Backup** — Export notification history as JSON/CSV; backup/restore the Drift database
- [ ] **Bulk Select & Batch Actions** — Select multiple notifications and dismiss, save, share, or clear them in bulk
- [ ] **Snooze Notifications** — Temporarily hide a notification and bring it back after a configurable time period
- [ ] **Custom Alert Rules** — Rules engine: vibrate, flash LED, or mute based on app, channel, keywords, or time of day
- [ ] **Home Screen Widget** — Android App Widget showing recent notifications directly on the home screen
- [ ] **Enhanced Dashboard Analytics** — Hourly heatmap, app leaderboard, notification volume trends, peak times
- [ ] **Tag / Label System** — User-assignable tags (Work, Personal, Finance, Travel) to categorize notifications
- [ ] **Notification Notes / Annotations** — Add personal notes to any notification for context
- [ ] **Advanced Filtering** — Multi-criteria filters combining app, keyword, date range, and channel
- [ ] **Dark Theme Polish** — Review all screens for consistent dark mode support

## Low Priority

- [ ] **Notification Forwarding** — Forward notifications to Telegram bot, email, or webhook
- [ ] **Regex-Based Filtering** — Advanced pattern-based notification filtering using regular expressions
- [ ] **Notification Categories Tab Bar** — Separate tabs on home screen: All, Unread, Saved, Alerts
- [ ] **Read Receipt Tracking** — Mark notifications as read/unread with visual indicator
- [ ] **Markdown Rendering** — Render rich text notification content properly
- [ ] **In-App Preview** — Expandable notification content on the card itself without navigating to detail screen
- [ ] **Duplicate Detection** — Collapse near-identical notifications (same app, same/similar title)
- [ ] **Time-Based Auto-Cleanup** — Auto-delete notifications older than a user-set duration
- [ ] **Lock Screen / Secure Mode** — Hide notification content, require biometric auth to view sensitive notifications
- [ ] **Quick Action Shortcuts** — Android launcher shortcuts (long-press app icon) for key screens

## Tech Debt & Improvements

- [ ] **launchApp Bug Fix** — Handle apps with no launch intent gracefully (see bug section above)
- [ ] **Icon Cache Size Management** — LRU eviction for SharedPreferences icon storage that grows unbounded
- [ ] **Notification List Virtualization** — Add pagination limits to home screen fetch for performance
- [ ] **Error Handling** — Surface `sendTestNotification` fallback failures to the user
- [ ] **Unit / Widget Test Coverage** — Add meaningful tests for critical flows (capture, launch, filtering)
- [ ] **CI Pipeline** — GitHub Actions for automated build, lint, test on PRs
- [ ] **Update Android Target SDK** — Stay current with latest API level requirements

---

> **Tip**: Prioritize the **launchApp bug fix** first — it's the most impactful user-facing issue.
> **Save/Share Notification** and **Notification Search** are queued as the next feature work.
