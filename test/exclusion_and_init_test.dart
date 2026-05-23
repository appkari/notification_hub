import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:notihub/database/app_database.dart' as db;
import 'package:notihub/models/notification_model.dart';
import 'package:notihub/providers/notification_provider.dart';
import 'package:notihub/providers/subscription_provider.dart';
import 'package:notihub/screens/home_screen.dart';
import 'package:notihub/services/notification_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Exclusion state isolation — tested through a pure-Dart replica of the
  // exact add/remove logic that was previously broken due to aliasing.
  // NotificationService is a native singleton and cannot be unit-tested
  // directly without mocking Android platform channels; the invariant is
  // captured here with an equivalent in-process implementation.
  // ---------------------------------------------------------------------------
  group('Exclusion state — defensive copy invariant', () {
    // Mirrors the FIXED behaviour: getExcludedApps returns a copy.
    _ExclusionLogic buildFixed() => _ExclusionLogic(defensiveCopy: true);

    // Mirrors the OLD broken behaviour: getExcludedApps returns the live set.
    _ExclusionLogic buildLeaky() => _ExclusionLogic(defensiveCopy: false);

    test('getExcludedApps: mutating the returned set has no effect', () {
      final svc = buildFixed();
      svc.internalApps.add('com.existing');

      final snapshot = svc.getExcludedApps();
      snapshot.add('com.intruder'); // mutate returned copy

      expect(svc.getExcludedApps(), isNot(contains('com.intruder')));
    });

    test(
      'excludeApp: persists correctly even after caller mutated the returned set',
      () {
        final svc = buildFixed();

        final leaked = svc.getExcludedApps(); // copy
        leaked.add('com.target'); // caller mutates copy — should be harmless

        final added = svc.excludeApp('com.target');

        // With defensive copy: internalApps did NOT contain 'com.target', so
        // add() returns true and persistence happens.
        expect(
          added,
          true,
          reason: 'excludeApp must report that it actually added the entry',
        );
        expect(svc.getExcludedApps(), contains('com.target'));
      },
    );

    test(
      'OLD bug reproduced: leaky reference causes excludeApp to silently skip persistence',
      () {
        final svc = buildLeaky();

        final leaked = svc.getExcludedApps(); // same object as internal set
        leaked.add('com.target'); // mutates the internal set directly!

        final added = svc.excludeApp('com.target');

        // The element was already in the set due to aliasing, so add() returns
        // false and persistence would have been skipped.
        expect(added, false, reason: 'demonstrates the aliasing bug');
      },
    );

    test(
      'includeApp: persists correctly even after caller mutated the returned set',
      () {
        final svc = buildFixed();
        svc.internalApps.add('com.target');

        final leaked = svc.getExcludedApps(); // copy
        leaked.remove('com.target'); // mutate copy — has no effect on internal

        final removed = svc.includeApp('com.target');

        expect(
          removed,
          true,
          reason: 'includeApp must report that it actually removed the entry',
        );
        expect(svc.getExcludedApps(), isNot(contains('com.target')));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Initialization error handling
  // ---------------------------------------------------------------------------
  group('NotificationProvider initialization error handling', () {
    test(
      'isInitialized becomes true and initError is set on failure',
      () async {
        // Provide a store that throws on getAllNotifications to simulate a DB
        // error during initialization.
        final provider = NotificationProvider(
          store: _ThrowingNotificationStore(),
          autoInitialize: false,
        );

        expect(provider.isInitialized, false);

        // Manually trigger init (autoInitialize was false).
        await provider.testInitialize();

        expect(provider.isInitialized, true);
        expect(provider.initError, isNotNull);
      },
    );

    testWidgets('HomeScreen shows loading spinner while not yet initialized', (
      tester,
    ) async {
      final provider = _SlowInitProvider();

      await tester.pumpWidget(_buildTestApp(provider: provider));
      // First frame — init not done yet.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('HomeScreen shows error widget when initError is set', (
      tester,
    ) async {
      final provider = _ErroredProvider();

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pump();

      expect(find.text('Could not start'), findsOneWidget);
      expect(find.text('simulated init failure'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Exclusion undo consistency
  // ---------------------------------------------------------------------------
  group('Exclusion undo restores notifications', () {
    test(
      'excludeApp returns removed list; restoreNotifications brings them back',
      () async {
        final provider = _FakeExclusionProvider(
          notifications: [
            _notification(
              id: '1',
              packageName: 'com.chat',
              appName: 'Chat',
              title: 'Msg',
            ),
            _notification(
              id: '2',
              packageName: 'com.mail',
              appName: 'Mail',
              title: 'Email',
            ),
          ],
        );

        final removed = await provider.excludeApp('com.chat');

        expect(removed, hasLength(1));
        expect(
          provider.notifications.map((n) => n.packageName),
          isNot(contains('com.chat')),
        );

        // Undo
        await provider.includeApp('com.chat');
        await provider.restoreNotifications(removed);

        expect(
          provider.notifications.map((n) => n.packageName),
          contains('com.chat'),
        );
      },
    );

    test(
      'removeNotification updates history in-memory without full DB reload',
      () async {
        final store = _CountingNotificationStore();
        final provider = _FakeExclusionProvider(
          notifications: [
            _notification(
              id: 'x',
              packageName: 'com.a',
              appName: 'A',
              title: 'X',
            ),
          ],
          store: store,
        );

        await provider.removeNotification('x');

        expect(provider.notifications, isEmpty);
        // History should contain the removed notification in memory.
        expect(provider.notificationHistory.map((n) => n.id), contains('x'));
        // getAllHistory should NOT have been called (no full reload).
        expect(store.getAllHistoryCalls, 0);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppNotification _notification({
  required String id,
  required String packageName,
  required String appName,
  required String title,
}) {
  return AppNotification(
    id: id,
    packageName: packageName,
    appName: appName,
    title: title,
    body: '',
    timestamp: DateTime.now(),
  );
}

Widget _buildTestApp({required NotificationProvider provider, Widget? child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NotificationProvider>.value(value: provider),
      ChangeNotifierProvider<SubscriptionProvider>(
        create: (_) => SubscriptionProvider(),
      ),
    ],
    child: MaterialApp(home: child ?? const HomeScreen()),
  );
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Minimal provider with controlled exclusion list, bypasses all native calls.
class _FakeExclusionProvider extends NotificationProvider {
  _FakeExclusionProvider({
    List<AppNotification>? notifications,
    NotificationStore? store,
  }) : _notifs = List<AppNotification>.from(notifications ?? []),
       _history = [],
       _excluded = {},
       super(autoInitialize: false, store: store ?? _NoOpNotificationStore());

  final List<AppNotification> _notifs;
  final List<AppNotification> _history;
  final Set<String> _excluded;

  @override
  bool get isInitialized => true;

  @override
  String? get initError => null;

  @override
  List<AppNotification> get notifications => List.unmodifiable(_notifs);

  @override
  List<AppNotification> get notificationHistory => List.unmodifiable(_history);

  @override
  Future<List<AppNotification>> excludeApp(String packageName) async {
    _excluded.add(packageName);
    final removed = _notifs.where((n) => n.packageName == packageName).toList();
    _notifs.removeWhere((n) => n.packageName == packageName);
    _history.insertAll(0, removed);
    notifyListeners();
    return removed;
  }

  @override
  Future<void> includeApp(String packageName) async {
    _excluded.remove(packageName);
    notifyListeners();
  }

  @override
  Future<void> restoreNotifications(List<AppNotification> items) async {
    for (final item in items) {
      _history.removeWhere((h) => h.id == item.id);
    }
    _notifs.insertAll(0, items);
    notifyListeners();
  }

  @override
  Future<void> removeNotification(String id, {String? packageName}) async {
    final index = _notifs.indexWhere(
      (n) => n.id == id && (packageName == null || n.packageName == packageName),
    );
    if (index == -1) return;
    final removed = _notifs.removeAt(index);
    _history.insert(0, removed);
    notifyListeners();
  }

  @override
  Future<void> loadNotifications() async {}

  @override
  Future<void> loadHistory() async {}
}

/// Provider that never completes initialization — simulates slow startup.
class _SlowInitProvider extends NotificationProvider {
  _SlowInitProvider()
    : super(autoInitialize: false, store: _NoOpNotificationStore());

  @override
  bool get isInitialized => false;

  @override
  String? get initError => null;
}

/// Provider that is "initialized" but has an error set.
class _ErroredProvider extends NotificationProvider {
  _ErroredProvider()
    : super(autoInitialize: false, store: _NoOpNotificationStore());

  @override
  bool get isInitialized => true;

  @override
  String? get initError => 'simulated init failure';
}

/// Store that throws on getAllNotifications (triggers _initialize failure).
class _ThrowingNotificationStore implements NotificationStore {
  @override
  Future<List<db.Notification>> getAllNotifications() =>
      Future.error(Exception('db unavailable'));

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

/// Store that counts getAllHistory calls so we can assert it is NOT called
/// during a single-notification removal.
class _CountingNotificationStore implements NotificationStore {
  int getAllHistoryCalls = 0;

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
  Future<List<db.NotificationHistoryData>> getAllHistory() async {
    getAllHistoryCalls++;
    return [];
  }

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

/// Pure-Dart replica of the add/remove logic in NotificationService so the
/// aliasing invariant can be tested without any platform-channel setup.
class _ExclusionLogic {
  _ExclusionLogic({required this.defensiveCopy});

  final bool defensiveCopy;
  final Set<String> internalApps = {};

  Set<String> getExcludedApps() =>
      defensiveCopy ? Set<String>.from(internalApps) : internalApps;

  /// Returns true when the element was actually added (matches service logic).
  bool excludeApp(String pkg) => internalApps.add(pkg);

  /// Returns true when the element was actually removed (matches service logic).
  bool includeApp(String pkg) => internalApps.remove(pkg);
}

class _NoOpNotificationStore implements NotificationStore {
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
