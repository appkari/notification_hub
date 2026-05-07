import 'package:flutter/material.dart'
    show
        AlertDialog,
        BorderRadius,
        BorderSide,
        BoxDecoration,
        BuildContext,
        Card,
        CircleAvatar,
        Colors,
        Column,
        Container,
        EdgeInsets,
        FontWeight,
        FutureBuilder,
        Icon,
        Icons,
        ListTile,
        MemoryImage,
        Navigator,
        Padding,
        RoundedRectangleBorder,
        ScaffoldMessenger,
        SnackBar,
        SnackBarAction,
        State,
        StatefulWidget,
        Text,
        TextButton,
        TextStyle,
        ValueKey,
        Widget,
        showDialog,
        Dismissible,
        DismissDirection,
        Alignment,
        Row,
        MainAxisSize,
        SizedBox,
        Theme,
        BoxShadow,
        Offset,
        TextOverflow,
        LinearGradient;
import 'package:provider/provider.dart' show Provider, Consumer;
import 'package:flutter/foundation.dart' show Uint8List, VoidCallback;
import 'dart:convert' show base64Decode;

import '../../models/notification_model.dart' show AppNotification;
import '../../providers/notification_provider.dart' show NotificationProvider;
import '../../providers/subscription_provider.dart' show SubscriptionProvider;
import '../../services/icon_cache_service.dart' show IconCacheService;
import 'notification_item.dart' show DismissibleNotificationItem;

class AppNotificationCard extends StatefulWidget {
  final String packageName;
  final List<AppNotification> appNotifications;
  final VoidCallback? onDismissed;

  const AppNotificationCard({
    super.key,
    required this.packageName,
    required this.appNotifications,
    this.onDismissed,
  });

  @override
  AppNotificationCardState createState() => AppNotificationCardState();
}

class AppNotificationCardState extends State<AppNotificationCard> {
  // final bool _isDismissed = false;

  void _showExcludeAppDialog(String packageName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Exclude App'),
            content: const Text(
              'Do you want to exclude this app from notification capture? Notifications from this app will no longer be collected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final provider = Provider.of<NotificationProvider>(
                    context,
                    listen: false,
                  );
                  provider.excludeApp(packageName);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('App will no longer be tracked'),
                      action: SnackBarAction(
                        label: 'UNDO',
                        onPressed: () {
                          provider.includeApp(packageName);
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Exclude'),
              ),
            ],
          ),
    );
  }

  // void _showClearAppNotificationsDialog(String packageName) {
  //   showDialog(
  //     context: context,
  //     builder:
  //         (context) => AlertDialog(
  //           title: const Text('Clear Notifications'),
  //           content: const Text(
  //             'Are you sure you want to clear all notifications for this app?',
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text('Cancel'),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 Provider.of<NotificationProvider>(
  //                   context,
  //                   listen: false,
  //                 ).clearAppNotifications(packageName);
  //                 Navigator.pop(context);
  //               },
  //               child: const Text('Clear'),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  Widget _buildDefaultIcon() {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.notifications,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mostRecentNotification = widget.appNotifications.first;
    final appName =
        (mostRecentNotification.appName.isNotEmpty &&
                mostRecentNotification.appName !=
                    mostRecentNotification.packageName)
            ? mostRecentNotification.appName
            : widget.packageName.split('.').last;

    return Dismissible(
      key: ValueKey(widget.packageName),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24.0),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      onDismissed: (direction) async {
        final messenger = ScaffoldMessenger.of(context);
        if (widget.onDismissed != null) {
          await Future.sync(widget.onDismissed!);
        }
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('All notifications for $appName cleared')),
        );
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              FutureBuilder<Uint8List?>(
                future: IconCacheService().getIcon(widget.packageName),
                builder: (context, snapshot) {
                  Widget leadingWidget;

                  if (snapshot.hasData && snapshot.data != null) {
                    leadingWidget = CircleAvatar(
                      backgroundImage: MemoryImage(snapshot.data!),
                      backgroundColor: Colors.transparent,
                      radius: 22,
                    );
                  } else if (mostRecentNotification.iconData?.isNotEmpty ==
                      true) {
                    try {
                      leadingWidget = CircleAvatar(
                        backgroundImage: MemoryImage(
                          base64Decode(mostRecentNotification.iconData!),
                        ),
                        backgroundColor: Colors.transparent,
                        radius: 22,
                      );
                    } catch (e) {
                      leadingWidget = _buildDefaultIcon();
                    }
                  } else {
                    leadingWidget = _buildDefaultIcon();
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 2,
                    ),
                    leading: leadingWidget,
                    title: Text(
                      appName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: Text(
                      mostRecentNotification.title.isNotEmpty
                          ? mostRecentNotification.title
                          : 'Latest notification available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Consumer<SubscriptionProvider>(
                      builder: (context, subscriptionProvider, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (subscriptionProvider.isPremium) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.tertiary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${widget.appNotifications.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    onTap: () async {
                      final provider = Provider.of<NotificationProvider>(
                        context,
                        listen: false,
                      );
                      final success = await provider.launchApp(
                        widget.packageName,
                      );
                      if (!success) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not launch $appName'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      _showExcludeAppDialog(widget.packageName);
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              ...widget.appNotifications.map(
                (notification) => DismissibleNotificationItem(
                  notification: notification,
                  onDismissed: (notificationId) {
                    // The actual dismissal is handled by DismissibleNotificationItem
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
