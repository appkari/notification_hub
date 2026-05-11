import '../database/app_database.dart';

abstract class NotificationStore {
  Future<List<Notification>> getAllNotifications();

  Future<void> insertNotification(NotificationsCompanion entry);

  Future<void> deleteNotification(String id);

  Future<void> clearNotifications();

  Future<List<NotificationHistoryData>> getAllHistory();

  Future<void> insertHistory(NotificationHistoryCompanion entry);

  Future<void> deleteHistory(String id);

  Future<void> clearHistory();

  Future<void> deleteHistoryOlderThan(DateTime cutoff);

  Future<List<Notification>> getPaginatedNotifications(int offset, int limit);

  Future<void> restoreFromHistory(
    List<NotificationsCompanion> entries,
    List<String> historyIds,
  );
}

class DriftNotificationStore implements NotificationStore {
  DriftNotificationStore([AppDatabase? database])
    : _database = database ?? AppDatabase();

  final AppDatabase _database;

  @override
  Future<void> clearHistory() => _database.clearHistory();

  @override
  Future<void> clearNotifications() => _database.clearNotifications();

  @override
  Future<void> deleteHistory(String id) => _database.deleteHistory(id);

  @override
  Future<void> deleteHistoryOlderThan(DateTime cutoff) =>
      _database.deleteHistoryOlderThan(cutoff);

  @override
  Future<void> deleteNotification(String id) =>
      _database.deleteNotification(id);

  @override
  Future<List<NotificationHistoryData>> getAllHistory() =>
      _database.getAllHistory();

  @override
  Future<List<Notification>> getAllNotifications() =>
      _database.getAllNotifications();

  @override
  Future<List<Notification>> getPaginatedNotifications(int offset, int limit) =>
      _database.getPaginatedNotifications(offset, limit);

  @override
  Future<void> insertHistory(NotificationHistoryCompanion entry) =>
      _database.insertHistory(entry);

  @override
  Future<void> insertNotification(NotificationsCompanion entry) =>
      _database.insertNotification(entry);

  @override
  Future<void> restoreFromHistory(
    List<NotificationsCompanion> entries,
    List<String> historyIds,
  ) => _database.restoreFromHistory(entries, historyIds);
}
