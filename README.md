# Notification Hub

A centralized Flutter application for capturing, organizing, and managing notifications from various apps on your device.

## Features

- **Centralized Notification Management**: View all your notifications in one place
- **App Grouping**: Notifications are neatly organized by app for better management
- **Notification Filtering**: Exclude specific apps from notification capture with a simple long press
- **Dashmon Integration**: View notification statistics and patterns with Dashmon integration
- **Privacy Focused**: All data stays on your device with no cloud uploads

## Roadmap

See [TODO.md](TODO.md) for the planned features, bug tracker, and tech debt backlog.

## Device Setup

### Android Setup

1. **Grant Notification Listener Permission**:
   - Go to Settings > Apps > Special app access > Notification access
   - Find and enable "Notification Hub"

2. **Additional Steps for Some Devices**:
   - On some Android versions, you may need to enable additional permissions in Settings > Apps > Notification Hub > Permissions
   - Ensure "Display over other apps" is enabled if available

3. **Battery Optimization**:
   - To ensure reliable background operation, disable battery optimization for Notification Hub
   - Go to Settings > Apps > Notification Hub > Battery > Unrestricted



## Usage

### Main Features

1. **Permission Setup**: Grant notification access permission when first launching the app
2. **Viewing Notifications**: All notifications are grouped by app in the main screen
3. **Excluding Apps**: Long press on an app name to exclude it from notification capture
4. **Managing Excluded Apps**: Go to settings to view and restore excluded apps
5. **Dashmon Integration**: View notification metrics and patterns through the Dashmon feature

### How to Exclude an App

1. Long press on any app name in the main screen
2. Confirm the exclusion in the dialog that appears
3. Use the UNDO option in the snackbar if needed, or restore later from Settings

## Development

This project is built with Flutter and uses:

- Provider pattern for state management
- SharedPreferences for local storage
- Flutter Local Notifications for notification handling

## Development Flavors

This app supports multiple flavors for different environments:

### Available Flavors

- **Development**: For development and testing
  - App Name: "Notification Hub Dev"
  - Package ID: `in.appkari.notihub.dev`
  - Debug mode enabled
  
- **Production**: For release builds
  - App Name: "Notification Hub"
  - Package ID: `in.appkari.notihub`
  - Debug mode disabled

### Running Different Flavors

**Using Flutter Command Line:**

```bash
# Development flavor
flutter run --flavor development -t lib/main_development.dart

# Production flavor
flutter run --flavor production -t lib/main_production.dart

# Release build for production
flutter build apk --flavor production -t lib/main_production.dart
```

**Using VS Code:**

Use the launch configurations in `.vscode/launch.json`:
- "Development" - Run development flavor in debug mode
- "Production" - Run production flavor in debug mode
- "Development (Profile)" - Run development flavor in profile mode
- "Production (Release)" - Run production flavor in release mode

### Platform Support

This app is **Android-only**. iOS, Windows, Linux, macOS, and web platforms have been removed to focus exclusively on Android functionality.

## Getting Started with Development

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Ensure you have notification permissions enabled on your Android device
4. Run the app with one of the flavor commands above
