import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notihub/database/app_database.dart' as db;
import 'package:notihub/models/notification_model.dart';
import 'package:notihub/providers/notification_provider.dart';
import 'package:notihub/services/notification_service.dart';
import 'package:notihub/services/notification_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationProvider.getNotificationsByApp', () {
    late FakeNotificationProvider provider;

    setUp(() {
      provider = FakeNotificationProvider(
        isListening: true,
        notifications: [
          _notification(
            id: '1',
            packageName: 'com.chat',
            appName: 'Chat',
            title: 'Msg A',
          ),
          _notification(
            id: '2',
            packageName: 'com.chat',
            appName: 'Chat',
            title: 'Msg B',
            minutesAgo: 1,
          ),
          _notification(
            id: '3',
            packageName: 'com.mail',
            appName: 'Mail',
            title: 'Inbox',
            minutesAgo: 2,
          ),
        ],
      );
    });

    test('groups notifications by package name', () {
      final groups = provider.getNotificationsByApp();

      expect(groups.keys, containsAll(['com.chat', 'com.mail']));
      expect(groups['com.chat'], hasLength(2));
      expect(groups['com.mail'], hasLength(1));
    });

    test('sorts notifications within each group newest first', () {
      final groups = provider.getNotificationsByApp();
      final chatNotifs = groups['com.chat']!;

      expect(chatNotifs[0].title, 'Msg A');
      expect(chatNotifs[1].title, 'Msg B');
    });

    test('respects pagination', () {
      final page0 = provider.getNotificationsByApp(page: 0, pageSize: 2);
      expect(page0.values.expand((list) => list).length, 2);

      final page1 = provider.getNotificationsByApp(page: 1, pageSize: 2);
      expect(page1.values.expand((list) => list).length, 1);
    });

    test('excludes removed notifications', () {
      final providerWithRemoved = FakeNotificationProvider(
        isListening: true,
        notifications: [
          _notification(
            id: '1',
            packageName: 'com.chat',
            appName: 'Chat',
            title: 'Visible',
          ),
          AppNotification(
            id: '2',
            packageName: 'com.chat',
            appName: 'Chat',
            title: 'Removed',
            body: 'Body',
            timestamp: DateTime.now(),
            isRemoved: true,
          ),
        ],
      );

      final groups = providerWithRemoved.getNotificationsByApp();
      final chatNotifs = groups['com.chat']!;
      expect(chatNotifs, hasLength(1));
      expect(chatNotifs[0].title, 'Visible');
    });

    test('returns empty map when no notifications', () {
      final emptyProvider = FakeNotificationProvider(
        isListening: true,
        notifications: [],
      );

      final groups = emptyProvider.getNotificationsByApp();
      expect(groups, isEmpty);
    });
  });

  group('NotificationProvider clear and restore', () {
    test('clearAllNotifications moves all to history', () async {
      final provider = FakeNotificationProvider(
        isListening: true,
        notifications: [
          _notification(
            id: 'a',
            packageName: 'com.a',
            appName: 'A',
            title: 'N1',
          ),
          _notification(
            id: 'b',
            packageName: 'com.b',
            appName: 'B',
            title: 'N2',
          ),
        ],
      );

      final cleared = await provider.clearAllNotifications();

      expect(cleared, hasLength(2));
      expect(provider.notifications, isEmpty);
      expect(provider.notificationHistory, hasLength(2));
    });

    test('clearAppNotifications removes only the target app', () async {
      final provider = FakeNotificationProvider(
        isListening: true,
        notifications: [
          _notification(
            id: '1',
            packageName: 'com.chat',
            appName: 'Chat',
            title: 'M1',
          ),
          _notification(
            id: '2',
            packageName: 'com.chat',
            appName: 'Chat',
            title: 'M2',
          ),
          _notification(
            id: '3',
            packageName: 'com.mail',
            appName: 'Mail',
            title: 'E1',
          ),
        ],
      );

      final removed = await provider.clearAppNotifications('com.chat');

      expect(removed, hasLength(2));
      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.first.packageName, 'com.mail');
      expect(provider.notificationHistory, hasLength(2));
    });

    test('removeNotification moves single item to history', () async {
      final provider = FakeNotificationProvider(
        isListening: true,
        notifications: [
          _notification(
            id: 'x',
            packageName: 'com.a',
            appName: 'A',
            title: 'X',
          ),
          _notification(
            id: 'y',
            packageName: 'com.b',
            appName: 'B',
            title: 'Y',
          ),
        ],
      );

      await provider.removeNotification('x');

      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.first.id, 'y');
      expect(provider.notificationHistory.first.id, 'x');
    });

    test('removeNotification does nothing for unknown id', () async {
      final provider = FakeNotificationProvider(
        isListening: true,
        notifications: [
          _notification(
            id: 'z',
            packageName: 'com.a',
            appName: 'A',
            title: 'Z',
          ),
        ],
      );

      await provider.removeNotification('nonexistent');

      expect(provider.notifications, hasLength(1));
      expect(provider.notificationHistory, isEmpty);
    });

    test('restoreNotification moves item back from history', () async {
      final notif = _notification(
        id: 'restore',
        packageName: 'com.a',
        appName: 'A',
        title: 'Restore Me',
      );
      final provider = FakeNotificationProvider(
        isListening: true,
        notifications: [],
        history: [notif],
      );

      await provider.restoreNotification(notif);

      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.first.id, 'restore');
      expect(provider.notificationHistory, isEmpty);
    });

    test('restoreNotifications restores multiple items', () async {
      final items = [
        _notification(
          id: 'r1',
          packageName: 'com.a',
          appName: 'A',
          title: 'R1',
        ),
        _notification(
          id: 'r2',
          packageName: 'com.b',
          appName: 'B',
          title: 'R2',
        ),
      ];
      final provider = FakeNotificationProvider(
        isListening: true,
        notifications: [],
        history: items,
      );

      await provider.restoreNotifications(items);

      expect(provider.notifications, hasLength(2));
      expect(provider.notificationHistory, isEmpty);
    });
  });

  group('NotificationProvider permission flow', () {
    test('requestPermission starts listening on success', () async {
      final provider = FakeNotificationProvider(
        isListening: false,
        requestPermissionResult: true,
      );

      final result = await provider.requestPermission();

      expect(result, true);
      expect(provider.isListening, true);
      expect(provider.requestPermissionCalls, 1);
    });

    test('requestPermission does not start listening on failure', () async {
      final provider = FakeNotificationProvider(
        isListening: false,
        requestPermissionResult: false,
      );

      final result = await provider.requestPermission();

      expect(result, false);
      expect(provider.isListening, false);
    });
  });

  group('NotificationProvider.loadMoreNotifications', () {
    test(
      'loadNotifications filters out excluded channels from stored data',
      () async {
        final service = NotificationService();
        await service.excludeChannel('com.chat', 'social');
        final store = _LoadMoreNotificationStore(
          allNotifications: [
            _dbNotification(
              id: 'excluded-channel',
              packageName: 'com.chat',
              title: 'Excluded channel',
              channelId: 'social',
            ),
            _dbNotification(
              id: 'included-channel',
              packageName: 'com.chat',
              title: 'Included channel',
              channelId: 'updates',
            ),
          ],
        );
        final provider = NotificationProvider(
          autoInitialize: false,
          store: store,
          notificationService: service,
          enableSummaryNotificationUpdates: false,
        );

        await provider.loadNotifications();

        expect(provider.notifications, hasLength(1));
        expect(provider.notifications.single.id, 'included-channel');
      },
    );

    test('loadMoreNotifications filters out excluded channels', () async {
      final service = NotificationService();
      await service.excludeChannel('com.chat', 'social');
      final store = _LoadMoreNotificationStore(
        paginatedNotifications: {
          0: [
            _dbNotification(
              id: 'excluded-channel',
              packageName: 'com.chat',
              title: 'Excluded channel',
              channelId: 'social',
            ),
            _dbNotification(
              id: 'included-channel',
              packageName: 'com.chat',
              title: 'Included channel',
              channelId: 'updates',
            ),
          ],
        },
      );
      final provider = NotificationProvider(
        autoInitialize: false,
        store: store,
        notificationService: service,
      );

      final hasMoreData = await provider.loadMoreNotifications();

      expect(hasMoreData, isFalse);
      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.single.id, 'included-channel');
    });

    test(
      'advances DB pagination offset even when a full fetched page is excluded',
      () async {
        final service = NotificationService();
        await service.excludeApp('com.excluded');
        final store = _LoadMoreNotificationStore(
          paginatedNotifications: {
            0: List<db.Notification>.generate(
              20,
              (index) => _dbNotification(
                id: 'excluded-$index',
                packageName: 'com.excluded',
                title: 'Excluded $index',
              ),
            ),
            20: [
              _dbNotification(
                id: 'included-1',
                packageName: 'com.included',
                title: 'Included 1',
              ),
            ],
          },
        );
        final provider = NotificationProvider(
          autoInitialize: false,
          store: store,
          notificationService: service,
        );

        final hasMoreAfterFirstPage = await provider.loadMoreNotifications();

        expect(hasMoreAfterFirstPage, isTrue);
        expect(provider.notifications, isEmpty);
        expect(store.requestedOffsets, [0]);

        final hasMoreAfterSecondPage = await provider.loadMoreNotifications();

        expect(hasMoreAfterSecondPage, isFalse);
        expect(store.requestedOffsets, [0, 20]);
        expect(provider.notifications, hasLength(1));
        expect(provider.notifications.single.packageName, 'com.included');
      },
    );

    test(
      'resets loading state if pagination throws to avoid blocking retries',
      () async {
        final provider = NotificationProvider(
          autoInitialize: false,
          store: _LoadMoreNotificationStore(shouldThrowOnPaginatedRead: true),
          notificationService: NotificationService(),
        );

        await expectLater(
          provider.loadMoreNotifications(),
          throwsA(isA<StateError>()),
        );
        expect(provider.isLoadingMore, isFalse);
      },
    );
  });
}

AppNotification _notification({
  required String id,
  required String packageName,
  required String appName,
  required String title,
  String body = 'Body',
  int minutesAgo = 0,
  bool hasContentIntent = false,
  String? key,
}) {
  return AppNotification(
    id: id,
    packageName: packageName,
    appName: appName,
    title: title,
    body: body,
    timestamp: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    hasContentIntent: hasContentIntent,
    key: key,
  );
}

class FakeNotificationProvider extends NotificationProvider {
  FakeNotificationProvider({
    required bool isListening,
    List<AppNotification>? notifications,
    List<AppNotification>? history,
    this.requestPermissionResult = true,
  }) : _isListeningValue = isListening,
       _notificationsValue = List<AppNotification>.from(
         notifications ?? const [],
       ),
       _historyValue = List<AppNotification>.from(history ?? const []),
       super(autoInitialize: false, store: _FakeNotificationStore());

  @override
  bool get isInitialized => true;

  @override
  String? get initError => null;

  bool _isListeningValue;
  final bool requestPermissionResult;
  final List<AppNotification> _notificationsValue;
  final List<AppNotification> _historyValue;

  int requestPermissionCalls = 0;
  final List<String> clearAppCalls = [];

  @override
  List<AppNotification> get notifications =>
      List.unmodifiable(_notificationsValue);

  @override
  Map<String, List<AppNotification>> getNotificationsByApp({
    int page = 0,
    int pageSize = 20,
  }) {
    final grouped = <String, List<AppNotification>>{};
    final pageItems = _notificationsValue
        .where((n) => !n.isRemoved)
        .skip(page * pageSize)
        .take(pageSize);
    for (final notification in pageItems) {
      grouped.putIfAbsent(notification.packageName, () => []).add(notification);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return grouped;
  }

  @override
  List<AppNotification> get notificationHistory =>
      List.unmodifiable(_historyValue);

  @override
  bool get isListening => _isListeningValue;

  @override
  Future<void> loadNotifications() async {}

  @override
  Future<void> loadHistory() async {}

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    if (requestPermissionResult) {
      _isListeningValue = true;
      notifyListeners();
    }
    return requestPermissionResult;
  }

  @override
  Future<List<AppNotification>> clearAppNotifications(
    String packageName,
  ) async {
    clearAppCalls.add(packageName);
    final removed = _notificationsValue
        .where((n) => n.packageName == packageName)
        .toList();
    _notificationsValue.removeWhere((n) => n.packageName == packageName);
    _historyValue.insertAll(0, removed);
    notifyListeners();
    return removed;
  }

  @override
  Future<void> removeNotification(String id, {String? packageName}) async {
    final index = _notificationsValue.indexWhere(
      (n) =>
          n.id == id && (packageName == null || n.packageName == packageName),
    );
    if (index == -1) return;
    final removed = _notificationsValue.removeAt(index);
    _historyValue.insert(0, removed);
    notifyListeners();
  }

  @override
  Future<void> restoreNotification(AppNotification notification) async {
    _historyValue.removeWhere((item) => item.id == notification.id);
    _notificationsValue.insert(0, notification);
    notifyListeners();
  }

  @override
  Future<void> restoreNotifications(List<AppNotification> notifications) async {
    for (final notification in notifications) {
      _historyValue.removeWhere((item) => item.id == notification.id);
    }
    _notificationsValue.insertAll(0, notifications);
    notifyListeners();
  }

  @override
  Future<List<AppNotification>> clearAllNotifications() async {
    final cleared = List<AppNotification>.from(_notificationsValue);
    _historyValue.insertAll(0, cleared);
    _notificationsValue.clear();
    notifyListeners();
    return cleared;
  }
}

class _FakeNotificationStore implements NotificationStore {
  @override
  Future<void> clearHistory() async {}
  @override
  Future<void> clearNotifications() async {}
  @override
  Future<void> deleteHistory(String id) async {}
  @override
  Future<void> deleteHistoryOlderThan(DateTime cutoff) async {}
  @override
  Future<void> deleteNotification(String id) async {}
  @override
  Future<List<db.NotificationHistoryData>> getAllHistory() async => [];
  @override
  Future<List<db.Notification>> getAllNotifications() async => [];
  @override
  Future<List<db.Notification>> getPaginatedNotifications(
    int offset,
    int limit,
  ) async => [];
  @override
  Future<void> insertHistory(db.NotificationHistoryCompanion entry) async {}
  @override
  Future<void> insertNotification(db.NotificationsCompanion entry) async {}
  @override
  Future<void> restoreFromHistory(
    List<db.NotificationsCompanion> entries,
    List<String> historyIds,
  ) async {}
}

class _LoadMoreNotificationStore implements NotificationStore {
  _LoadMoreNotificationStore({
    this.shouldThrowOnPaginatedRead = false,
    this.paginatedNotifications = const {},
    this.allNotifications = const [],
  });

  final bool shouldThrowOnPaginatedRead;
  final Map<int, List<db.Notification>> paginatedNotifications;
  final List<db.Notification> allNotifications;
  final List<int> requestedOffsets = [];

  @override
  Future<void> clearHistory() async {}
  @override
  Future<void> clearNotifications() async {}
  @override
  Future<void> deleteHistory(String id) async {}
  @override
  Future<void> deleteHistoryOlderThan(DateTime cutoff) async {}
  @override
  Future<void> deleteNotification(String id) async {}
  @override
  Future<List<db.NotificationHistoryData>> getAllHistory() async => [];
  @override
  Future<List<db.Notification>> getAllNotifications() async => allNotifications;
  @override
  Future<List<db.Notification>> getPaginatedNotifications(
    int offset,
    int limit,
  ) async {
    requestedOffsets.add(offset);
    if (shouldThrowOnPaginatedRead) {
      throw StateError('Simulated paginated read failure');
    }
    return paginatedNotifications[offset] ?? [];
  }

  @override
  Future<void> insertHistory(db.NotificationHistoryCompanion entry) async {}
  @override
  Future<void> insertNotification(db.NotificationsCompanion entry) async {}
  @override
  Future<void> restoreFromHistory(
    List<db.NotificationsCompanion> entries,
    List<String> historyIds,
  ) async {}
}

db.Notification _dbNotification({
  required String id,
  required String packageName,
  required String title,
  String? channelId,
  String? channelName,
}) {
  return db.Notification(
    id: id,
    packageName: packageName,
    appName: packageName,
    title: title,
    body: 'Body',
    timestamp: DateTime.now(),
    isRemoved: false,
    hasContentIntent: false,
    channelId: channelId,
    channelName: channelName,
  );
}
