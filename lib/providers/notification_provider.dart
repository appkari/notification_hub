import 'dart:async' show StreamSubscription, Timer;
import 'dart:ui' show AppLifecycleState;
import 'package:flutter/foundation.dart'
    show ChangeNotifier, debugPrint, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import '../models/notification_model.dart'
    show AppNotification, NotificationChannelInfo;
import '../services/notification_service.dart' show NotificationService;
import '../services/icon_cache_service.dart' show IconCacheService;
import '../database/app_database.dart'
    show
        Notification,
        NotificationHistoryData,
        NotificationsCompanion,
        NotificationHistoryCompanion;
import '../services/notification_store.dart'
    show DriftNotificationStore, NotificationStore;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:drift/drift.dart' show Value;

class NotificationProvider with ChangeNotifier {
  NotificationProvider({
    NotificationService? notificationService,
    IconCacheService? iconCacheService,
    NotificationStore? store,
    bool autoInitialize = true,
  }) : _notificationService = notificationService ?? NotificationService(),
       _ownsNotificationService = notificationService == null,
       _iconCacheService = iconCacheService ?? IconCacheService(),
       _store = store ?? DriftNotificationStore() {
    if (autoInitialize) {
      _initialize();
    }
  }

  final NotificationService _notificationService;
  final bool _ownsNotificationService;
  final IconCacheService _iconCacheService;
  final NotificationStore _store;
  List<AppNotification> _notifications = [];
  List<AppNotification> _notificationHistory = [];
  int _historyDays = 7;
  bool _isInitialized = false;
  StreamSubscription<AppNotification>? _subscription;

  // Throttle rapid notifyListeners() calls triggered by frequent updates
  // (e.g. ongoing progress notifications that arrive many times per second).
  Timer? _notifyThrottle;
  bool _hasPendingUiUpdate = false;
  static const _notifyDebounceDuration = Duration(milliseconds: 100);

  AppLifecycleListener? _lifecycleListener;

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get notificationHistory => _notificationHistory;
  bool get isListening => _notificationService.isListening;
  bool get isInitialized => _isInitialized;
  NotificationService get notificationService => _notificationService;

  bool _isLoadingMore = false;
  bool _hasMoreData = true; // Assuming initially there's more data to load
  String? _initError;

  // Rate limiting for debug logs
  DateTime? _lastLogTime;
  String? _lastLoggedNotificationId;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String? get initError => _initError;

  void _scheduleNotifyListeners() {
    _hasPendingUiUpdate = true;
    if (_notifyThrottle != null) {
      return;
    }
    _notifyThrottle = Timer(_notifyDebounceDuration, () {
      _notifyThrottle = null;
      if (!_hasPendingUiUpdate) {
        return;
      }
      _hasPendingUiUpdate = false;
      notifyListeners();
    });
  }

  @visibleForTesting
  Future<void> testInitialize() => _initialize();

  // Initialize the provider
  Future<void> _initialize() async {
    debugPrint('NotificationProvider: Initializing...');
    try {
      final prefs = await SharedPreferences.getInstance();
      _historyDays = prefs.getInt('historyDays') ?? 7;
      await _notificationService.initialize();
      final hasPermission = await _notificationService.isPermissionGranted();
      if (hasPermission) {
        await _notificationService.startListening();
      }
      await loadNotifications();
      await loadHistory();
      _startListeningToNotifications();
      _setupLifecycleListener();
      _isInitialized = true;
      _initError = null;
      debugPrint(
        'NotificationProvider: Initialization complete. isInitialized: $_isInitialized',
      );
    } catch (e, stack) {
      debugPrint('NotificationProvider: Initialization failed: $e\n$stack');
      _isInitialized = true; // Unblock the UI so it doesn't spin forever
      _initError = e.toString();
    }
    notifyListeners();
  }

  // Make method public
  Future<void> loadNotifications() async {
    debugPrint('NotificationProvider: Loading notifications from database...');
    try {
      final dbNotifs = await _store.getAllNotifications();
      final excludedApps = await _notificationService.getExcludedApps();
      _notifications =
          dbNotifs
              .map(_fromDbNotification)
              .where((n) => !excludedApps.contains(n.packageName))
              .toList();
      _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      debugPrint(
        'NotificationProvider: Loaded ${_notifications.length} notifications from database (${dbNotifs.length - _notifications.length} filtered by exclusion).',
      );
    } catch (e) {
      debugPrint('NotificationProvider: Error loading notifications: $e');
      // Clear and recreate database on error
      try {
        await _store.clearNotifications();
        _notifications = [];
        debugPrint('NotificationProvider: Database cleared due to error.');
      } catch (clearError) {
        debugPrint(
          'NotificationProvider: Error clearing database: $clearError',
        );
        _notifications = [];
      }
    }
    _updatePersistentSummaryNotification();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    debugPrint('NotificationProvider: Loading history from database...');
    try {
      final cutoff = DateTime.now().subtract(Duration(days: _historyDays));
      // Remove old history
      await _store.deleteHistoryOlderThan(cutoff);
      _notificationHistory =
          (await _store.getAllHistory())
              .where((h) => h.timestamp.isAfter(cutoff))
              .map(_fromDbNotificationHistory)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      debugPrint(
        'NotificationProvider: Loaded ${_notificationHistory.length} history entries from database.',
      );
    } catch (e) {
      debugPrint('NotificationProvider: Error loading history: $e');
      // Clear history on error
      try {
        await _store.clearHistory();
        _notificationHistory = [];
        debugPrint('NotificationProvider: History cleared due to error.');
      } catch (clearError) {
        debugPrint('NotificationProvider: Error clearing history: $clearError');
        _notificationHistory = [];
      }
    }
    notifyListeners();
  }

  // Start listening to notification stream
  void _startListeningToNotifications() {
    debugPrint(
      'NotificationProvider: Starting to listen to notification stream...',
    );
    _subscription?.cancel();
    _subscription = _notificationService.notificationsStream.listen((
      notification,
    ) async {
      // Rate limiting for debug logs - only log once per second for the same notification
      final now = DateTime.now();
      final shouldLog =
          _lastLogTime == null ||
          _lastLoggedNotificationId != notification.id ||
          now.difference(_lastLogTime!).inSeconds >= 1;

      if (shouldLog && notification.title.isNotEmpty) {
        debugPrint(
          'Provider received notification: \\${notification.title} from \\${notification.packageName}',
        );
        _lastLogTime = now;
        _lastLoggedNotificationId = notification.id;
      }

      if (notification.iconData != null) {
        await _iconCacheService.cacheIcon(
          notification.packageName,
          notification.iconData!,
        );
      }

      if (notification.isRemoved) {
        // Find the notification by id
        final idx = _notifications.indexWhere((n) => n.id == notification.id);
        if (idx != -1) {
          if (_notificationService.removeIfSourceAppRemoves) {
            final removedNotif = _notifications[idx].copyWith(isRemoved: true);
            await addToHistory(removedNotif);
            await _store.deleteNotification(removedNotif.id);
            _notifications.removeAt(idx);
            if (shouldLog) {
              debugPrint(
                'NotificationProvider: Notification \\${removedNotif.id} deleted from active database due to source app removal.',
              );
            }
            notifyListeners();
          } else {
            if (shouldLog) {
              debugPrint(
                'NotificationProvider: Source app removed notification, but setting is off. Keeping in app.',
              );
            }
          }
        }
      } else {
        final existingIdx = _notifications.indexWhere(
          (n) => n.id == notification.id,
        );
        if (existingIdx == -1) {
          // New notification — insert at top
          _notifications.insert(0, notification);
          if (shouldLog) {
            debugPrint(
              'NotificationProvider: Inserting new notification \\${notification.id} into database...',
            );
          }
          await _store.insertNotification(_toDbNotification(notification));
          if (shouldLog) {
            debugPrint(
              'NotificationProvider: Notification \\${notification.id} inserted into database.',
            );
          }
        } else {
          // Ongoing notification updated in place (e.g. download/install progress)
          _notifications[existingIdx] = notification;
          if (shouldLog) {
            debugPrint(
              'NotificationProvider: Updated existing notification \\${notification.id} in place.',
            );
          }
          await _store.insertNotification(_toDbNotification(notification));
        }
      }
      if (shouldLog) {
        debugPrint(
          'Provider notifications list now has \\${_notifications.length} items',
        );
      }
      _updatePersistentSummaryNotification();
      // Debounce UI rebuilds so rapid-fire updates (e.g. progress bars) are
      // coalesced into a single frame instead of causing continuous redraws.
      _scheduleNotifyListeners();
    });
  }

  // Open notification listener settings directly
  Future<void> openNotificationSettings() async {
    await _notificationService.openNotificationSettings();
  }

  // Request notification listening permission
  Future<bool> requestPermission() async {
    final permissionGranted = await _notificationService.requestPermission();
    if (permissionGranted) {
      await _notificationService.startListening();
      notifyListeners();
    }
    return permissionGranted;
  }

  // Start notification listening
  Future<void> startListening() async {
    await _notificationService.startListening();
    notifyListeners();
  }

  // Stop notification listening
  Future<void> stopListening() async {
    await _notificationService.stopListening();
    notifyListeners();
  }

  void setRemoveIfSourceAppRemoves(bool value) {
    _notificationService.setRemoveIfSourceAppRemoves(value);
    notifyListeners();
  }

  // Clear all notifications, returns the cleared list for undo
  Future<List<AppNotification>> clearAllNotifications() async {
    debugPrint('NotificationProvider: Clearing all notifications...');
    final cleared = List<AppNotification>.from(_notifications);

    // Add all current notifications to history in the database
    await _archiveNotifications(cleared);

    // Clear all notifications from the database
    debugPrint(
      'NotificationProvider: Clearing all notifications from database...',
    );
    await _store.clearNotifications();
    debugPrint(
      'NotificationProvider: All notifications cleared from database.',
    );

    // Clear all notifications from the system tray
    await _notificationService.clearAllNotifications();

    // Clear all notifications from the in-memory list
    _notifications = [];
    _updatePersistentSummaryNotification();
    notifyListeners();
    return cleared;
  }

  // Get list of excluded app package names
  Future<Set<String>> getExcludedApps() async {
    return await _notificationService.getExcludedApps();
  }

  // Check if an app is excluded
  Future<bool> isAppExcluded(String packageName) async {
    return await _notificationService.isAppExcluded(packageName);
  }

  // Exclude an app from notification capture.
  // Returns the list of removed notifications so the caller can offer undo.
  Future<List<AppNotification>> excludeApp(String packageName) async {
    await _notificationService.excludeApp(packageName);

    debugPrint(
      'NotificationProvider: Excluding app $packageName, removing existing notifications...',
    );

    // Remove existing notifications for this app from the active list
    final removed =
        _notifications.where((n) => n.packageName == packageName).toList();
    _notifications.removeWhere((n) => n.packageName == packageName);

    // Archive to history and clean up from DB / system tray
    await _archiveNotifications(removed);
    for (final notification in removed) {
      await _notificationService.removeNotificationFromSystemTray(
        notification.key,
      );
      await _store.deleteNotification(notification.id);
    }

    _updatePersistentSummaryNotification();
    notifyListeners();

    debugPrint(
      'NotificationProvider: Removed ${removed.length} notifications for excluded app $packageName.',
    );
    return removed;
  }

  // Include a previously excluded app
  Future<void> includeApp(String packageName) async {
    await _notificationService.includeApp(packageName);
    notifyListeners();
  }

  Future<Set<String>> getExcludedChannelKeys() async {
    return await _notificationService.getExcludedChannelKeys();
  }

  Future<bool> isChannelExcluded(String packageName, String channelId) async {
    return await _notificationService.isChannelExcluded(packageName, channelId);
  }

  Future<void> setChannelEnabled({
    required String packageName,
    required String channelId,
    required bool enabled,
  }) async {
    if (enabled) {
      await _notificationService.includeChannel(packageName, channelId);
    } else {
      await _notificationService.excludeChannel(packageName, channelId);
      await clearChannelNotifications(
        packageName: packageName,
        channelId: channelId,
      );
    }
    notifyListeners();
  }

  // Add pagination support
  Future<List<AppNotification>> getPaginatedNotifications(
    int page,
    int pageSize,
  ) async {
    // final allNotifications = await _notificationService.getNotifications(); // Remove this line
    // Use the database to get paginated notifications instead
    final newNotifications = await _store.getPaginatedNotifications(
      page * pageSize, // Offset
      pageSize, // Limit
    );
    return newNotifications
        .map(_fromDbNotification)
        .toList(); // Map DB results to AppNotification
  }

  // Clear notifications for a specific app, returns the cleared list for undo
  Future<List<AppNotification>> clearAppNotifications(
    String packageName,
  ) async {
    debugPrint(
      'NotificationProvider: Clearing notifications for app: $packageName...',
    );
    // Find all notifications for this app
    final appNotifications =
        _notifications.where((n) => n.packageName == packageName).toList();

    // Remove from in-memory list first to avoid intermediate rebuilds
    // while the dismissed Dismissible is still in the tree.
    _notifications.removeWhere((n) => n.packageName == packageName);
    _updatePersistentSummaryNotification();
    notifyListeners();

    // Archive to history and clean up system tray / DB
    await _archiveNotifications(appNotifications);
    for (final notification in appNotifications) {
      await _notificationService.removeNotificationFromSystemTray(
        notification.key,
      );
      await _store.deleteNotification(notification.id);
    }

    return appNotifications;
  }

  Future<void> clearChannelNotifications({
    required String packageName,
    required String channelId,
  }) async {
    final channelNotifications =
        _notifications
            .where(
              (n) => n.packageName == packageName && n.channelId == channelId,
            )
            .toList();

    await _archiveNotifications(channelNotifications);
    for (final notification in channelNotifications) {
      await _notificationService.removeNotificationFromSystemTray(
        notification.key,
      );
      await _store.deleteNotification(notification.id);
    }

    _notifications.removeWhere(
      (n) => n.packageName == packageName && n.channelId == channelId,
    );
    _updatePersistentSummaryNotification();
    notifyListeners();
  }

  // Add method to remove a single notification
  Future<void> removeNotification(String id) async {
    debugPrint('NotificationProvider: Removing notification with id: $id...');
    try {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index == -1) {
        debugPrint(
          'NotificationProvider: Notification $id not found, skipping removal.',
        );
        return;
      }
      final notification = _notifications[index];

      // Persist to history DB and update in-memory history directly — avoids
      // a full DB reload (loadHistory) for every single notification removal.
      await _store.insertHistory(_toDbHistory(notification));
      _notificationHistory.insert(0, notification);

      await _notificationService.removeNotificationFromSystemTray(
        notification.key,
      );

      // Remove from active notifications
      _notifications.removeAt(index);
      debugPrint(
        'NotificationProvider: Deleting notification $id from active database...',
      );
      await _store.deleteNotification(id);
      debugPrint(
        'NotificationProvider: Notification $id deleted from active database.',
      );
      _updatePersistentSummaryNotification();
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationProvider: Error removing notification $id: $e');
    }
  }

  // Get notifications grouped by app with pagination
  Map<String, List<AppNotification>> getNotificationsByApp({
    int page = 0,
    int pageSize = 20,
  }) {
    final groupedNotifications = <String, List<AppNotification>>{};
    final startIndex = page * pageSize;

    final paginatedNotifications = _notifications
        .where((n) => !n.isRemoved)
        .skip(startIndex)
        .take(pageSize);

    for (final notification in paginatedNotifications) {
      groupedNotifications
          .putIfAbsent(notification.packageName, () => [])
          .add(notification);
    }

    groupedNotifications.forEach((key, list) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    return groupedNotifications;
  }

  Map<String, List<AppNotification>> getNotificationsByChannel(
    List<AppNotification> notifications,
  ) {
    final groupedNotifications = <String, List<AppNotification>>{};

    for (final notification in notifications) {
      final channelKey = notification.channelId ?? '__uncategorized__';
      groupedNotifications.putIfAbsent(channelKey, () => []).add(notification);
    }

    groupedNotifications.forEach((key, list) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    return groupedNotifications;
  }

  List<NotificationChannelInfo> getKnownNotificationChannels() {
    final channels = <String, NotificationChannelInfo>{};

    void collect(AppNotification notification) {
      final channelId = notification.channelId;
      if (channelId == null || channelId.isEmpty) {
        return;
      }

      final storageKey = '${notification.packageName}|$channelId';
      final existing = channels[storageKey];
      channels[storageKey] = NotificationChannelInfo(
        packageName: notification.packageName,
        appName: notification.appName,
        channelId: channelId,
        channelName: _displayChannelName(notification),
        notificationCount: (existing?.notificationCount ?? 0) + 1,
        iconData: existing?.iconData ?? notification.iconData,
      );
    }

    for (final notification in _notifications) {
      collect(notification);
    }
    for (final notification in _notificationHistory) {
      collect(notification);
    }

    final result =
        channels.values.toList()..sort((a, b) {
          final appCompare = a.appName.toLowerCase().compareTo(
            b.appName.toLowerCase(),
          );
          if (appCompare != 0) {
            return appCompare;
          }
          return a.channelName.toLowerCase().compareTo(
            b.channelName.toLowerCase(),
          );
        });
    return result;
  }

  void setLoadingMore(bool value) {
    _isLoadingMore = value;
    notifyListeners();
  }

  void setHasMoreData(bool value) {
    _hasMoreData = value;
    notifyListeners();
  }

  // Add load more notifications method
  Future<bool> loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMoreData) return false;

    _isLoadingMore = true;
    notifyListeners();

    final currentLength = _notifications.length;
    final pageSize = 20;

    final newNotifications = await _store.getPaginatedNotifications(
      currentLength, // Start from the current number of notifications
      pageSize,
    );

    final excludedApps = await _notificationService.getExcludedApps();
    final filtered =
        newNotifications
            .map(_fromDbNotification)
            .where((n) => !excludedApps.contains(n.packageName))
            .toList();
    _notifications.addAll(filtered);

    _isLoadingMore = false;
    _hasMoreData =
        newNotifications.length ==
        pageSize; // Assume more data if we got a full page
    notifyListeners();

    return _hasMoreData;
  }

  // Send a test notification
  Future<void> sendTestNotification({
    String title = 'Test Notification',
    String body = 'This is a test notification',
  }) async {
    debugPrint('NotificationProvider: Sending test notification...');
    try {
      await _notificationService.startListening();
      await _notificationService.sendTestNotification(title: title, body: body);
      debugPrint('NotificationProvider: Test notification sent successfully.');
    } catch (e) {
      debugPrint('NotificationProvider: Error sending test notification: $e');
      rethrow;
    }
  }

  // Launch the app that created the notification
  Future<bool> launchApp(String packageName) async {
    return await _notificationService.launchApp(packageName);
  }

  Future<bool> openAppInfo(String packageName) async {
    return await _notificationService.openAppInfo(packageName);
  }

  Future<bool> openAppNotificationSettings(String packageName) async {
    return await _notificationService.openAppNotificationSettings(packageName);
  }

  Future<bool> openChannelNotificationSettings({
    required String packageName,
    required String channelId,
  }) async {
    return await _notificationService.openChannelNotificationSettings(
      packageName: packageName,
      channelId: channelId,
    );
  }

  // Execute the original notification action
  Future<bool> executeNotificationAction(String? key) async {
    return await _notificationService.executeNotificationAction(key);
  }

  // Add to notification history
  Future<void> addToHistory(
    AppNotification notification, {
    bool reloadHistory = true,
  }) async {
    debugPrint(
      'NotificationProvider: Adding notification \\${notification.id} to history database...',
    );
    await _store.insertHistory(_toDbHistory(notification));
    debugPrint(
      'NotificationProvider: Notification \\${notification.id} added to history database.',
    );
    if (reloadHistory) {
      await loadHistory();
    }
  }

  // Restore a notification from history (undo)
  Future<void> restoreNotification(AppNotification notification) async {
    debugPrint(
      'NotificationProvider: Restoring notification ${notification.id} from history...',
    );
    await _store.insertNotification(
      NotificationsCompanion(
        id: Value(notification.id),
        packageName: Value(notification.packageName),
        appName: Value(notification.appName),
        title: Value(notification.title),
        body: Value(notification.body),
        timestamp: Value(notification.timestamp),
        iconData: Value(notification.iconData),
        isRemoved: Value(notification.isRemoved),
        key: Value(notification.key),
        hasContentIntent: Value(notification.hasContentIntent),
        channelId: Value(notification.channelId),
        channelName: Value(notification.channelName),
      ),
    );
    await _store.deleteHistory(notification.id);
    debugPrint(
      'NotificationProvider: Notification ${notification.id} deleted from history database.',
    );
    await loadNotifications();
    await loadHistory();
    debugPrint(
      'NotificationProvider: Notification ${notification.id} restored and lists reloaded.',
    );
  }

  // Restore multiple notifications from history (bulk undo)
  Future<void> restoreNotifications(List<AppNotification> notifications) async {
    debugPrint(
      'NotificationProvider: Restoring ${notifications.length} notifications from history...',
    );
    await _store.restoreFromHistory(
      notifications.map(_toDbNotification).toList(),
      notifications.map((n) => n.id).toList(),
    );
    await loadNotifications();
    await loadHistory();
    debugPrint(
      'NotificationProvider: ${notifications.length} notifications restored and lists reloaded.',
    );
  }

  // Helper to convert DB row to AppNotification
  AppNotification _fromDbNotification(Notification n) => AppNotification(
    id: n.id,
    packageName: n.packageName,
    appName: n.appName,
    title: n.title,
    body: n.body,
    timestamp: n.timestamp,
    iconData: n.iconData,
    isRemoved: n.isRemoved,
    key: n.key,
    hasContentIntent: n.hasContentIntent,
    channelId: n.channelId,
    channelName: n.channelName,
  );
  AppNotification _fromDbNotificationHistory(NotificationHistoryData n) =>
      AppNotification(
        id: n.id,
        packageName: n.packageName,
        appName: n.appName,
        title: n.title,
        body: n.body,
        timestamp: n.timestamp,
        iconData: n.iconData,
        isRemoved: n.isRemoved,
        key: n.key,
        hasContentIntent: n.hasContentIntent,
        channelId: n.channelId,
        channelName: n.channelName,
      );

  // Helper to convert AppNotification to NotificationsCompanion
  NotificationsCompanion _toDbNotification(AppNotification notification) {
    return NotificationsCompanion(
      id: Value(notification.id),
      packageName: Value(notification.packageName),
      appName: Value(notification.appName),
      title: Value(notification.title),
      body: Value(notification.body),
      timestamp: Value(notification.timestamp),
      iconData: Value(notification.iconData),
      isRemoved: Value(notification.isRemoved),
      key: Value(notification.key),
      hasContentIntent: Value(notification.hasContentIntent),
      channelId: Value(notification.channelId),
      channelName: Value(notification.channelName),
    );
  }

  // Helper to convert AppNotification to NotificationHistoryCompanion
  NotificationHistoryCompanion _toDbHistory(AppNotification notification) {
    return NotificationHistoryCompanion(
      id: Value(notification.id),
      packageName: Value(notification.packageName),
      appName: Value(notification.appName),
      title: Value(notification.title),
      body: Value(notification.body),
      timestamp: Value(notification.timestamp),
      iconData: Value(notification.iconData),
      isRemoved: Value(notification.isRemoved),
      key: Value(notification.key),
      hasContentIntent: Value(notification.hasContentIntent),
      channelId: Value(notification.channelId),
      channelName: Value(notification.channelName),
    );
  }

  String displayChannelName(AppNotification notification) {
    return _displayChannelName(notification);
  }

  String _displayChannelName(AppNotification notification) {
    final name = notification.channelName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final id = notification.channelId?.trim();
    if (id != null && id.isNotEmpty) {
      return _prettifyChannelId(id);
    }

    return 'Uncategorized';
  }

  String _prettifyChannelId(String value) {
    final normalized =
        value
            .replaceAll(RegExp(r'[_\-.]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (normalized.isEmpty) {
      return value;
    }

    return normalized
        .split(' ')
        .map((part) {
          if (part.isEmpty) {
            return part;
          }
          if (part.length == 1) {
            return part.toUpperCase();
          }
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  void _updatePersistentSummaryNotification() {
    // Count unique apps with notifications
    final appSet = <String>{};
    for (final n in _notifications) {
      if (!n.isRemoved) appSet.add(n.packageName);
    }
    final appCount = appSet.length;
    final notifCount = _notifications.where((n) => !n.isRemoved).length;
    if (notifCount == 0) {
      _notificationService.cancelPersistentSummaryNotification();
      return;
    }
    _notificationService.showPersistentSummaryNotification(
      appCount: appCount,
      notifCount: notifCount,
    );
  }

  void _setupLifecycleListener() {
    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onAppLifecycleStateChange,
    );
  }

  void _onAppLifecycleStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermissionOnResume();
    }
  }

  Future<void> _recheckPermissionOnResume() async {
    final hasPermission = await _notificationService.isPermissionGranted();
    if (hasPermission && !_notificationService.isListening) {
      debugPrint(
        'NotificationProvider: Permission granted on resume, starting listener.',
      );
      await _notificationService.startListening();
      notifyListeners();
    } else if (!hasPermission && _notificationService.isListening) {
      debugPrint(
        'NotificationProvider: Permission revoked on resume, stopping listener.',
      );
      await _notificationService.stopListening();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _notifyThrottle?.cancel();
    _subscription?.cancel();
    if (_ownsNotificationService) {
      _notificationService.dispose();
    }
    super.dispose();
  }

  Future<void> _archiveNotifications(
    List<AppNotification> notifications,
  ) async {
    for (final notification in notifications) {
      await addToHistory(notification, reloadHistory: false);
    }
    await loadHistory();
  }
}
