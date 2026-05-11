import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import 'app_notification_card.dart';

class NotificationListView extends StatelessWidget {
  const NotificationListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final groupedNotifications = provider.getNotificationsByApp();
        final appEntries =
            groupedNotifications.entries
                .where((entry) => entry.value.isNotEmpty)
                .toList();

        final DateTime veryEarlyDateTime = DateTime.fromMillisecondsSinceEpoch(
          0,
        );
        appEntries.sort((a, b) {
          final latestTimestampA = a.value
              .map((n) => n.timestamp)
              .fold<DateTime>(
                veryEarlyDateTime,
                (prev, current) => current.isAfter(prev) ? current : prev,
              );
          final latestTimestampB = b.value
              .map((n) => n.timestamp)
              .fold<DateTime>(
                veryEarlyDateTime,
                (prev, current) => current.isAfter(prev) ? current : prev,
              );
          return latestTimestampB.compareTo(latestTimestampA);
        });

        return RefreshIndicator(
          onRefresh: () async => await provider.loadNotifications(),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: appEntries.length,
                  itemBuilder: (context, index) {
                    final packageName = appEntries[index].key;
                    final appNotifications = List<AppNotification>.from(
                      appEntries[index].value,
                    );
                    appNotifications.sort(
                      (a, b) => b.timestamp.compareTo(a.timestamp),
                    );
                    if (appNotifications.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return AppNotificationCard(
                      packageName: packageName,
                      appNotifications: appNotifications,
                    );
                  },
                ),
              ),
              if (provider.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }
}
