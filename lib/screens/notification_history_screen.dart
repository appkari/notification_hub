import 'package:flutter/material.dart'
    show
        AppBar,
        BuildContext,
        Card,
        Center,
        CircleAvatar,
        Colors,
        EdgeInsets,
        FontWeight,
        Icon,
        Icons,
        ListTile,
        ListView,
        MemoryImage,
        NeverScrollableScrollPhysics,
        Opacity,
        Padding,
        Scaffold,
        State,
        StatefulWidget,
        Text,
        TextStyle,
        Widget,
        Column,
        CrossAxisAlignment;
import 'package:provider/provider.dart' show Consumer;
import 'dart:convert' show base64Decode;
import '../providers/notification_provider.dart' show NotificationProvider;
import '../models/notification_model.dart' show AppNotification;
import '../widgets/home/notification_item_widget.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification History')),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final history = provider.notificationHistory;
          if (history.isEmpty) {
            return const Center(child: Text('No cleared notifications.'));
          }
          // Group by package to avoid merging separate apps with the same label.
          final Map<String, List<AppNotification>> grouped = {};
          for (final n in history) {
            grouped.putIfAbsent(n.packageName, () => []).add(n);
          }
          final apps =
              grouped.keys.toList()..sort(
                (a, b) => grouped[b]!.first.timestamp.compareTo(
                  grouped[a]!.first.timestamp,
                ),
              );
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final packageName = apps[index];
              final appNotifications = grouped[packageName]!;
              final appName = appNotifications.first.appName;
              final iconData = appNotifications.first.iconData;
              Widget leadingWidget;
              if (iconData != null && iconData.isNotEmpty) {
                try {
                  leadingWidget = CircleAvatar(
                    backgroundImage: MemoryImage(base64Decode(iconData)),
                    backgroundColor: Colors.white,
                    radius: 22,
                  );
                } catch (e) {
                  leadingWidget = const CircleAvatar(
                    child: Icon(Icons.notifications),
                  );
                }
              } else {
                leadingWidget = const CircleAvatar(
                  child: Icon(Icons.notifications),
                );
              }
              return Opacity(
                opacity: 0.5,
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          leading: leadingWidget,
                          title: Text(
                            appName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text('${appNotifications.length} cleared'),
                        ),
                        Consumer<NotificationProvider>(
                          builder: (context, provider, _) {
                            final groupedByChannel = provider
                                .getNotificationsByChannel(appNotifications);
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
                                    final channelLabel = provider
                                        .displayChannelName(
                                          channelNotifications.first,
                                        );

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            4,
                                            16,
                                            0,
                                          ),
                                          child: Text(
                                            '$channelLabel (${channelNotifications.length})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount:
                                              channelNotifications.length,
                                          itemBuilder: (context, idx) {
                                            final notification =
                                                channelNotifications[idx];
                                            return NotificationItemWidget(
                                              notification: notification,
                                              enableInteractions: false,
                                            );
                                          },
                                        ),
                                      ],
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
            },
          );
        },
      ),
    );
  }
}
