import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notihub/database/app_database.dart' as db;
import 'package:notihub/models/notification_model.dart';
import 'package:notihub/providers/notification_provider.dart';
import 'package:notihub/providers/subscription_provider.dart';
import 'package:notihub/screens/home_screen.dart';
import 'package:notihub/screens/notification_history_screen.dart';
import 'package:notihub/services/notification_store.dart';
import 'package:notihub/widgets/home/app_notification_card.dart';
import 'package:notihub/widgets/home/notification_item.dart';
import 'package:notihub/widgets/home/notification_item_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows permission request while listener is disabled', (
    tester,
  ) async {
    final provider = FakeNotificationProvider(isListening: false);

    await tester.pumpWidget(
      _buildTestApp(provider: provider, child: const HomeScreen()),
    );

    expect(find.text('Notification Access Required'), findsOneWidget);
    expect(find.text('Grant Permission'), findsOneWidget);
  });

  testWidgets('grant permission updates home state', (tester) async {
    final provider = FakeNotificationProvider(isListening: false);

    await tester.pumpWidget(
      _buildTestApp(provider: provider, child: const HomeScreen()),
    );

    await tester.tap(find.text('Grant Permission'));
    await tester.pumpAndSettle();

    expect(provider.requestPermissionCalls, 1);
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('renders grouped app cards and clears an app once on swipe', (
    tester,
  ) async {
    final provider = FakeNotificationProvider(
      isListening: true,
      notifications: [
        _notification(
          id: '1',
          packageName: 'com.chat',
          appName: 'Chat',
          title: 'New message',
        ),
        _notification(
          id: '2',
          packageName: 'com.chat',
          appName: 'Chat',
          title: 'Another message',
          minutesAgo: 1,
        ),
        _notification(
          id: '3',
          packageName: 'com.mail',
          appName: 'Mail',
          title: 'Inbox update',
          minutesAgo: 2,
        ),
      ],
    );
    final appNotifications =
        provider.notifications
            .where((notification) => notification.packageName == 'com.chat')
            .toList();

    await tester.pumpWidget(
      _buildTestApp(
        provider: provider,
        child: Scaffold(
          body: AppNotificationCard(
            packageName: 'com.chat',
            appNotifications: appNotifications,
            onDismissed: () => provider.clearAppNotifications('com.chat'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('com.chat')),
      const Offset(-1200, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(provider.clearAppCalls, ['com.chat']);
    expect(find.text('Chat'), findsNothing);
  });

  testWidgets('dismissing a notification shows undo and restores it', (
    tester,
  ) async {
    final item = _notification(
      id: 'restore-me',
      packageName: 'com.mail',
      appName: 'Mail',
      title: 'Receipt',
    );
    final provider = FakeNotificationProvider(
      isListening: true,
      notifications: [item],
    );

    await tester.pumpWidget(
      _buildTestApp(
        provider: provider,
        child: Scaffold(
          body: DismissibleNotificationItem(
            notification: item,
            onDismissed: (_) {},
          ),
        ),
      ),
    );

    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(provider.notifications, isEmpty);
    expect(
      provider.notificationHistory.map((n) => n.id),
      contains('restore-me'),
    );
    expect(find.text('Notification deleted'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    expect(provider.notifications.map((n) => n.id), contains('restore-me'));
    expect(
      provider.notificationHistory.map((n) => n.id),
      isNot(contains('restore-me')),
    );
  });

  testWidgets(
    'live notification tap executes action then falls back to app launch',
    (tester) async {
      final provider = FakeNotificationProvider(
        isListening: true,
        executeActionResult: false,
        launchAppResult: true,
      );
      final notification = _notification(
        id: 'open-me',
        packageName: 'com.mail',
        appName: 'Mail',
        title: 'Open inbox',
        hasContentIntent: true,
        key: 'notif-key',
      );

      await tester.pumpWidget(
        _buildTestApp(
          provider: provider,
          child: Scaffold(
            body: NotificationItemWidget(notification: notification),
          ),
        ),
      );

      await tester.tap(find.text('Open inbox'));
      await tester.pumpAndSettle();

      expect(provider.executeActionCalls, ['notif-key']);
      expect(provider.launchAppCalls, ['com.mail']);
      expect(find.text('Opened Mail'), findsOneWidget);
    },
  );

  testWidgets('history screen items are read only', (tester) async {
    final historyItem = _notification(
      id: 'history-1',
      packageName: 'com.mail',
      appName: 'Mail',
      title: 'Archived',
    );
    final provider = FakeNotificationProvider(
      isListening: true,
      history: [historyItem],
    );

    await tester.pumpWidget(
      _buildTestApp(
        provider: provider,
        child: const NotificationHistoryScreen(),
      ),
    );

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Archived'));
    await tester.pumpAndSettle();

    expect(provider.launchAppCalls, isEmpty);
    expect(provider.executeActionCalls, isEmpty);
    expect(find.text('Opened Mail'), findsNothing);
  });
}

Widget _buildTestApp({
  required FakeNotificationProvider provider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationProvider>.value(value: provider),
      ChangeNotifierProvider<SubscriptionProvider>(
        create: (_) => SubscriptionProvider(),
      ),
    ],
    child: MaterialApp(home: child),
  );
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
    this.executeActionResult = false,
    this.launchAppResult = true,
  }) : _isListeningValue = isListening,
       _notificationsValue = List<AppNotification>.from(
         notifications ?? const [],
       ),
       _historyValue = List<AppNotification>.from(history ?? const []),
       super(autoInitialize: false, store: _FakeNotificationStore());

  bool _isListeningValue;
  final bool requestPermissionResult;
  final bool executeActionResult;
  final bool launchAppResult;
  final List<AppNotification> _notificationsValue;
  final List<AppNotification> _historyValue;

  int requestPermissionCalls = 0;
  final List<String> clearAppCalls = [];
  final List<String?> executeActionCalls = [];
  final List<String> launchAppCalls = [];

  @override
  List<AppNotification> get notifications =>
      List.unmodifiable(_notificationsValue);

  @override
  List<AppNotification> get notificationHistory =>
      List.unmodifiable(_historyValue);

  @override
  bool get isListening => _isListeningValue;

  @override
  Map<String, List<AppNotification>> getNotificationsByApp({
    int page = 0,
    int pageSize = 20,
  }) {
    final grouped = <String, List<AppNotification>>{};
    final pageItems = _notificationsValue.skip(page * pageSize).take(pageSize);
    for (final notification in pageItems) {
      if (notification.isRemoved) {
        continue;
      }
      grouped.putIfAbsent(notification.packageName, () => []).add(notification);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return grouped;
  }

  @override
  Future<void> loadNotifications() async {}

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
  Future<void> clearAppNotifications(String packageName) async {
    clearAppCalls.add(packageName);
    final removed =
        _notificationsValue
            .where((notification) => notification.packageName == packageName)
            .toList();
    _notificationsValue.removeWhere(
      (notification) => notification.packageName == packageName,
    );
    _historyValue.insertAll(0, removed);
    notifyListeners();
  }

  @override
  Future<void> removeNotification(String id) async {
    final index = _notificationsValue.indexWhere(
      (notification) => notification.id == id,
    );
    if (index == -1) {
      return;
    }
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
  Future<bool> executeNotificationAction(String? key) async {
    executeActionCalls.add(key);
    return executeActionResult;
  }

  @override
  Future<bool> launchApp(String packageName) async {
    launchAppCalls.add(packageName);
    return launchAppResult;
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
}
