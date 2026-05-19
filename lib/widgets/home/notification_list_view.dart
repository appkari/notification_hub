import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
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

        // getNotificationsByApp() already sorts each group descending, so
        // [0] is the newest notification — no need to fold across all items.
        appEntries.sort(
          (a, b) => b.value.first.timestamp.compareTo(a.value.first.timestamp),
        );

        return RefreshIndicator(
          onRefresh: () async => await provider.loadNotifications(),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: appEntries.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    final packageName = appEntries[index].key;
                    // Already sorted descending by getNotificationsByApp().
                    final appNotifications = appEntries[index].value;
                    if (appNotifications.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return AppNotificationCard(
                      key: ValueKey(packageName),
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
