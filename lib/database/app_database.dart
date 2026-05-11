import 'package:drift/drift.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:path/path.dart' as p show join;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;
import 'dart:io' show File;

part 'app_database.g.dart';

class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get packageName => text()();
  TextColumn get appName => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get iconData => text().nullable()();
  BoolColumn get isRemoved => boolean().withDefault(const Constant(false))();
  TextColumn get key => text().nullable()();
  BoolColumn get hasContentIntent =>
      boolean().withDefault(const Constant(false))();
  TextColumn get channelId => text().nullable()();
  TextColumn get channelName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NotificationHistory extends Table {
  TextColumn get id => text()();
  TextColumn get packageName => text()();
  TextColumn get appName => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get iconData => text().nullable()();
  BoolColumn get isRemoved => boolean().withDefault(const Constant(false))();
  TextColumn get key => text().nullable()();
  BoolColumn get hasContentIntent =>
      boolean().withDefault(const Constant(false))();
  TextColumn get channelId => text().nullable()();
  TextColumn get channelName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Notifications, NotificationHistory])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) {
      return m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(notifications, notifications.key);
        await m.addColumn(notificationHistory, notificationHistory.key);
      }
      if (from < 3) {
        await m.addColumn(notifications, notifications.hasContentIntent);
        await m.addColumn(
          notificationHistory,
          notificationHistory.hasContentIntent,
        );
      }
      if (from < 4) {
        await m.addColumn(notifications, notifications.channelId);
        await m.addColumn(notifications, notifications.channelName);
        await m.addColumn(notificationHistory, notificationHistory.channelId);
        await m.addColumn(notificationHistory, notificationHistory.channelName);
      }
    },
  );

  // Notification CRUD
  Future<List<Notification>> getAllNotifications() =>
      select(notifications).get();
  Future<void> insertNotification(NotificationsCompanion entry) =>
      into(notifications).insertOnConflictUpdate(entry);
  Future<void> deleteNotification(String id) =>
      (delete(notifications)..where((tbl) => tbl.id.equals(id))).go();
  Future<void> clearNotifications() => delete(notifications).go();

  // History CRUD
  Future<List<NotificationHistoryData>> getAllHistory() =>
      select(notificationHistory).get();
  Future<void> insertHistory(NotificationHistoryCompanion entry) =>
      into(notificationHistory).insertOnConflictUpdate(entry);
  Future<void> deleteHistory(String id) =>
      (delete(notificationHistory)..where((tbl) => tbl.id.equals(id))).go();
  Future<void> clearHistory() => delete(notificationHistory).go();
  Future<void> deleteHistoryOlderThan(DateTime cutoff) =>
      (delete(notificationHistory)
        ..where((tbl) => tbl.timestamp.isSmallerThan(Constant(cutoff)))).go();

  // Restore notifications from history in a single transaction
  Future<void> restoreFromHistory(
    List<NotificationsCompanion> entries,
    List<String> historyIds,
  ) {
    return transaction(() async {
      for (final entry in entries) {
        await into(notifications).insertOnConflictUpdate(entry);
      }
      for (final id in historyIds) {
        await (delete(notificationHistory)
          ..where((tbl) => tbl.id.equals(id))).go();
      }
    });
  }

  // Add pagination support for notifications
  Future<List<Notification>> getPaginatedNotifications(int offset, int limit) {
    return (select(notifications)
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
          ])
          ..limit(limit, offset: offset))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));

    // Ensure the database directory exists
    if (!dbFolder.existsSync()) {
      await dbFolder.create(recursive: true);
    }

    return NativeDatabase(file);
  });
}
