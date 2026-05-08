import 'package:flutter/material.dart'
    show
        AppBar,
        BuildContext,
        Card,
        CircleAvatar,
        Colors,
        Column,
        CrossAxisAlignment,
        Divider,
        EdgeInsets,
        Expanded,
        FontWeight,
        MemoryImage,
        Padding,
        Row,
        Scaffold,
        SizedBox,
        SingleChildScrollView,
        StatelessWidget,
        Text,
        TextStyle,
        Theme,
        Widget,
        FloatingActionButton,
        Icon,
        Icons,
        ScaffoldMessenger,
        SnackBar;
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart' show Provider;
import 'dart:convert' show base64Decode;

import '../models/notification_model.dart' show AppNotification;
import '../providers/notification_provider.dart' show NotificationProvider;

class NotificationDetailScreen extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('MMM d, y - h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text('Notification from ${notification.appName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final provider = Provider.of<NotificationProvider>(
            context,
            listen: false,
          );

          bool success = false;

          // If the notification has a content intent, execute it; otherwise launch the app
          if (notification.hasContentIntent && notification.key != null) {
            success = await provider.executeNotificationAction(
              notification.key,
            );
          } else {
            success = await provider.launchApp(notification.packageName);
          }

          if (!success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open ${notification.appName}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        icon: Icon(
          notification.hasContentIntent ? Icons.open_in_new : Icons.launch,
        ),
        label: Text(
          notification.hasContentIntent
              ? 'Open Content'
              : 'Open ${notification.appName}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildAppAvatar(context),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.appName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                dateTimeFormat.format(notification.timestamp),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      notification.body,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Technical Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Package Name:', notification.packageName),
            _buildDetailRow(
              'Channel:',
              notification.channelName?.isNotEmpty == true
                  ? notification.channelName!
                  : (notification.channelId?.isNotEmpty == true
                      ? notification.channelId!
                      : 'Uncategorized'),
            ),
            _buildDetailRow('Notification ID:', notification.id),
            _buildDetailRow(
              'Received at:',
              dateTimeFormat.format(notification.timestamp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppAvatar(BuildContext context) {
    // Try to show the app icon if available
    if (notification.iconData != null && notification.iconData!.isNotEmpty) {
      try {
        return CircleAvatar(
          backgroundColor: Colors.transparent,
          backgroundImage: MemoryImage(base64Decode(notification.iconData!)),
        );
      } catch (e) {
        // Fallback to default avatar if icon decoding fails
        return CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            notification.appName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        );
      }
    }

    // Default avatar with first letter if no icon is available
    return CircleAvatar(
      backgroundColor: Theme.of(context).primaryColor,
      child: Text(
        notification.appName[0].toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
