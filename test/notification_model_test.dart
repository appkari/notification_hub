import 'package:flutter_test/flutter_test.dart';
import 'package:notihub/models/notification_model.dart';

void main() {
  group('AppNotification', () {
    test('fromMap creates instance with all fields', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-id',
        'packageName': 'com.example',
        'appName': 'Example',
        'title': 'Hello',
        'body': 'World',
        'timestamp': now.millisecondsSinceEpoch,
        'iconData': 'base64data',
        'isRemoved': true,
        'key': 'notif-key',
        'hasContentIntent': true,
        'channelId': 'ch1',
        'channelName': 'General',
      };

      final notification = AppNotification.fromMap(map);

      expect(notification.id, 'test-id');
      expect(notification.packageName, 'com.example');
      expect(notification.appName, 'Example');
      expect(notification.title, 'Hello');
      expect(notification.body, 'World');
      expect(notification.iconData, 'base64data');
      expect(notification.isRemoved, true);
      expect(notification.key, 'notif-key');
      expect(notification.hasContentIntent, true);
      expect(notification.channelId, 'ch1');
      expect(notification.channelName, 'General');
    });

    test('fromMap handles missing optional fields', () {
      final map = <String, dynamic>{};

      final notification = AppNotification.fromMap(map);

      expect(notification.id, '');
      expect(notification.packageName, '');
      expect(notification.appName, 'Unknown App');
      expect(notification.title, '');
      expect(notification.body, '');
      expect(notification.iconData, isNull);
      expect(notification.isRemoved, false);
      expect(notification.key, isNull);
      expect(notification.hasContentIntent, false);
      expect(notification.channelId, isNull);
      expect(notification.channelName, isNull);
    });

    test('toMap round-trips with fromMap', () {
      final original = AppNotification(
        id: 'round-trip',
        packageName: 'com.test',
        appName: 'Test',
        title: 'Title',
        body: 'Body',
        timestamp: DateTime(2025, 1, 15, 10, 30),
        iconData: 'icon123',
        isRemoved: false,
        key: 'k1',
        hasContentIntent: true,
        channelId: 'channel-1',
        channelName: 'Channel One',
      );

      final map = original.toMap();
      final restored = AppNotification.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.packageName, original.packageName);
      expect(restored.appName, original.appName);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        original.timestamp.millisecondsSinceEpoch,
      );
      expect(restored.iconData, original.iconData);
      expect(restored.isRemoved, original.isRemoved);
      expect(restored.key, original.key);
      expect(restored.hasContentIntent, original.hasContentIntent);
      expect(restored.channelId, original.channelId);
      expect(restored.channelName, original.channelName);
    });

    test('copyWith overrides specified fields', () {
      final original = AppNotification(
        id: 'orig',
        packageName: 'com.a',
        appName: 'A',
        title: 'T1',
        body: 'B1',
        timestamp: DateTime(2025),
      );

      final copy = original.copyWith(
        title: 'T2',
        isRemoved: true,
        channelId: 'ch-new',
      );

      expect(copy.id, 'orig');
      expect(copy.packageName, 'com.a');
      expect(copy.title, 'T2');
      expect(copy.isRemoved, true);
      expect(copy.channelId, 'ch-new');
      expect(copy.body, 'B1');
    });

    test('copyWith preserves all fields when none specified', () {
      final original = AppNotification(
        id: 'keep',
        packageName: 'com.keep',
        appName: 'Keep',
        title: 'Keep Title',
        body: 'Keep Body',
        timestamp: DateTime(2025, 6, 1),
        iconData: 'keepIcon',
        isRemoved: true,
        key: 'keep-key',
        hasContentIntent: true,
        channelId: 'keep-ch',
        channelName: 'Keep Channel',
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.packageName, original.packageName);
      expect(copy.appName, original.appName);
      expect(copy.title, original.title);
      expect(copy.body, original.body);
      expect(copy.timestamp, original.timestamp);
      expect(copy.iconData, original.iconData);
      expect(copy.isRemoved, original.isRemoved);
      expect(copy.key, original.key);
      expect(copy.hasContentIntent, original.hasContentIntent);
      expect(copy.channelId, original.channelId);
      expect(copy.channelName, original.channelName);
    });
  });

  group('NotificationChannelInfo', () {
    test('storageKey combines packageName and channelId', () {
      const info = NotificationChannelInfo(
        packageName: 'com.example',
        appName: 'Example',
        channelId: 'messages',
        channelName: 'Messages',
        notificationCount: 5,
      );

      expect(info.storageKey, 'com.example|messages');
    });
  });
}
