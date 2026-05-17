import 'package:flutter/material.dart'
    show
        BuildContext,
        EdgeInsets,
        ElevatedButton,
        Icons,
        ScaffoldMessenger,
        SnackBar,
        SnackBarAction,
        Text,
        Widget,
        StatelessWidget;
import 'package:provider/provider.dart' show Provider;

import '../../providers/notification_provider.dart' show NotificationProvider;
import '../empty_state.dart' show EmptyState;

class PermissionRequestWidget extends StatelessWidget {
  const PermissionRequestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);

    return EmptyState(
      icon: Icons.notifications_active,
      title: 'Notification Access Required',
      message:
          'This app needs notification access permissions to capture and display notifications.',
      action: ElevatedButton(
        onPressed: () {
          provider.openNotificationSettings();
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: const Text(
                  'Enable "Notification Hub" in the list, then return to the app',
                ),
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Open Settings',
                  onPressed: provider.openNotificationSettings,
                ),
              ),
            );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text('Grant Permission'),
      ),
    );
  }
}
