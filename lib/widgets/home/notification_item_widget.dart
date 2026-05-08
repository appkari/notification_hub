import 'package:flutter/material.dart'
    show
        MaterialPageRoute,
        Padding,
        Column,
        Row,
        Expanded,
        Navigator,
        Text,
        TextOverflow,
        Widget,
        BuildContext,
        StatelessWidget,
        Theme,
        EdgeInsets,
        MainAxisAlignment,
        CrossAxisAlignment,
        InkWell,
        TextStyle,
        ScaffoldMessenger,
        SnackBar,
        Icon,
        Icons,
        SizedBox,
        SnackBarBehavior,
        SnackBarAction,
        Colors,
        debugPrint;
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart' show Provider;

import '../../models/notification_model.dart' show AppNotification;
import '../../screens/notification_detail_screen.dart'
    show NotificationDetailScreen;
import '../../providers/notification_provider.dart' show NotificationProvider;

class NotificationItemWidget extends StatelessWidget {
  final AppNotification notification;
  final bool enableInteractions;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    this.enableInteractions = true,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(
      notification.timestamp.year,
      notification.timestamp.month,
      notification.timestamp.day,
    );

    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');
    String timeText;

    if (notificationDate == today) {
      timeText = 'Today, ${timeFormat.format(notification.timestamp)}';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      timeText = 'Yesterday, ${timeFormat.format(notification.timestamp)}';
    } else {
      timeText =
          '${dateFormat.format(notification.timestamp)}, ${timeFormat.format(notification.timestamp)}';
    }

    return InkWell(
      onTap: () async {
        if (!enableInteractions) {
          return;
        }
        final provider = Provider.of<NotificationProvider>(
          context,
          listen: false,
        );

        bool success = false;

        // Try to execute the original notification action first
        if (notification.hasContentIntent && notification.key != null) {
          debugPrint(
            'Attempting to execute notification action for ${notification.key}',
          );
          success = await provider.executeNotificationAction(notification.key);
          debugPrint('Notification action result: $success');
        }

        // If that failed or wasn't available, try to launch the app
        if (!success) {
          debugPrint('Attempting to launch app: ${notification.packageName}');
          success = await provider.launchApp(notification.packageName);
          debugPrint('App launch result: $success');
        }

        // Show user feedback
        if (context.mounted) {
          if (success) {
            // Optional: Show brief success feedback
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opened ${notification.appName}'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            // Show error feedback
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open ${notification.appName}'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.red[300],
                action: SnackBarAction(
                  label: 'Try Again',
                  textColor: Colors.white,
                  onPressed: () async {
                    // Try launching the app directly as a last resort
                    final retrySuccess = await provider.launchApp(
                      notification.packageName,
                    );
                    if (!retrySuccess && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${notification.appName} could not be opened. It may have been uninstalled.',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          }
        }
      },
      onLongPress: () {
        if (!enableInteractions) {
          return;
        }
        // Long press shows the notification detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    NotificationDetailScreen(notification: notification),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((notification.channelName?.isNotEmpty ?? false) ||
                          (notification.channelId?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            notification.channelName?.isNotEmpty == true
                                ? notification.channelName!
                                : notification.channelId!,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (notification.title.isNotEmpty)
                        Text(
                          notification.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      enableInteractions
                          ? notification.hasContentIntent
                              ? Icons.open_in_new
                              : Icons.launch
                          : Icons.history,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeText,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (notification.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
