import 'package:flutter/material.dart'
    show
        AlertDialog,
        Alignment,
        BorderRadius,
        BorderSide,
        BoxDecoration,
        BuildContext,
        Card,
        CircleAvatar,
        Colors,
        Column,
        Container,
        CrossAxisAlignment,
        DismissDirection,
        Dismissible,
        EdgeInsets,
        Expanded,
        FontWeight,
        FutureBuilder,
        Icon,
        Icons,
        InkWell,
        ListTile,
        MainAxisSize,
        MemoryImage,
        Navigator,
        Offset,
        Padding,
        RoundedRectangleBorder,
        Row,
        Radius,
        ScaffoldMessenger,
        SafeArea,
        SizedBox,
        SnackBar,
        SnackBarAction,
        State,
        StatefulWidget,
        Text,
        TextButton,
        TextStyle,
        TextOverflow,
        Theme,
        ValueKey,
        Widget,
        Wrap,
        WrapCrossAlignment,
        showDialog,
        showModalBottomSheet,
        BoxShadow,
        LinearGradient;
import 'package:provider/provider.dart' show Consumer, Consumer2, Provider;
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
  Future<void> _showExcludeAppDialog(String packageName) async {
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

  Future<void> _showAppActionsSheet(String packageName, String appName) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);

    Future<void> handleAction(Future<bool> Function() action) async {
      Navigator.pop(context);
      final success = await action();
      if (!mounted || success) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open settings for $appName'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Exclude app'),
                onTap: () async {
                  Navigator.pop(context);
                  await _showExcludeAppDialog(packageName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification settings'),
                onTap:
                    () => handleAction(
                      () => provider.openAppNotificationSettings(packageName),
                    ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('App info'),
                onTap:
                    () => handleAction(() => provider.openAppInfo(packageName)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showChannelActionsSheet({
    required String appName,
    required String channelId,
    required String channelLabel,
  }) async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Exclude channel'),
                subtitle: Text(channelLabel),
                onTap: () async {
                  Navigator.pop(context);
                  await provider.setChannelEnabled(
                    packageName: widget.packageName,
                    channelId: channelId,
                    enabled: false,
                  );
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '$channelLabel in $appName will be ignored',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification settings'),
                subtitle: Text(channelLabel),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await provider
                      .openChannelNotificationSettings(
                        packageName: widget.packageName,
                        channelId: channelId,
                      );
                  if (!mounted || success) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not open channel settings'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
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

  String _headerSummary(NotificationProvider provider) {
    final channelCount =
        provider.getNotificationsByChannel(widget.appNotifications).length;
    final notificationCount = widget.appNotifications.length;
    final channelText = '$channelCount channel${channelCount == 1 ? '' : 's'}';
    final notificationText =
        '$notificationCount notification${notificationCount == 1 ? '' : 's'}';
    return '$notificationText • $channelText';
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
      onDismissed: (direction) {
        final messenger = ScaffoldMessenger.of(context);
        widget.onDismissed?.call();
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

                  return Consumer2<NotificationProvider, SubscriptionProvider>(
                    builder: (context, provider, subscriptionProvider, _) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
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
                          _showAppActionsSheet(widget.packageName, appName);
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                          child: Row(
                            children: [
                              leadingWidget,
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _headerSummary(provider),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (subscriptionProvider.isPremium) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(
                                          alpha: 0.18,
                                        ),
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
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.18),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
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
                              ),
                            ],
                          ),
                        ),
                      );
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
              Consumer<NotificationProvider>(
                builder: (context, provider, _) {
                  final groupedByChannel = provider.getNotificationsByChannel(
                    widget.appNotifications,
                  );
                  final channelEntries =
                      groupedByChannel.entries.toList()..sort((a, b) {
                        final channelA =
                            provider
                                .displayChannelName(a.value.first)
                                .toLowerCase();
                        final channelB =
                            provider
                                .displayChannelName(b.value.first)
                                .toLowerCase();
                        return channelA.compareTo(channelB);
                      });

                  return Column(
                    children:
                        channelEntries.map((entry) {
                          final channelNotifications = entry.value;
                          final channelLabel = provider.displayChannelName(
                            channelNotifications.first,
                          );
                          final channelId =
                              channelNotifications.first.channelId;

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        onTap:
                                            channelId == null ||
                                                    channelId.isEmpty
                                                ? null
                                                : () async {
                                                  final success = await provider
                                                      .openChannelNotificationSettings(
                                                        packageName:
                                                            widget.packageName,
                                                        channelId: channelId,
                                                      );
                                                  if (!context.mounted ||
                                                      success) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Could not open channel settings',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                                },
                                        onLongPress:
                                            channelId == null ||
                                                    channelId.isEmpty
                                                ? null
                                                : () =>
                                                    _showChannelActionsSheet(
                                                      appName: appName,
                                                      channelId: channelId,
                                                      channelLabel:
                                                          channelLabel,
                                                    ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            channelLabel,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${channelNotifications.length} notification${channelNotifications.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ...channelNotifications.map(
                                  (notification) => DismissibleNotificationItem(
                                    notification: notification,
                                    onDismissed: (notificationId) {},
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
