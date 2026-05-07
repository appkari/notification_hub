import 'package:flutter/material.dart'
    show
        AlertDialog,
        AlwaysStoppedAnimation,
        AppBar,
        BorderRadius,
        BorderSide,
        BuildContext,
        Builder,
        CircularProgressIndicator,
        Color,
        Colors,
        EdgeInsets,
        Expanded,
        FloatingActionButton,
        FontWeight,
        Icon,
        IconButton,
        Icons,
        MaterialPageRoute,
        Navigator,
        RoundedRectangleBorder,
        Row,
        Scaffold,
        ScaffoldMessenger,
        SizedBox,
        SnackBar,
        SnackBarAction,
        SnackBarBehavior,
        State,
        StatefulWidget,
        Text,
        TextButton,
        TextStyle,
        Widget,
        debugPrint,
        showDialog;
import 'package:provider/provider.dart' show Consumer, Provider;

import '../providers/notification_provider.dart' show NotificationProvider;
import '../widgets/empty_state.dart' show EmptyState;
import 'notification_history_screen.dart' show NotificationHistoryScreen;

// Import the new widgets
import '../widgets/home/permission_request_widget.dart';
import '../widgets/home/notification_list_view.dart';
// The following two imports are needed in the other files, not here anymore
// import '../widgets/home/app_notification_card.dart';
// import '../widgets/home/notification_item_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Remove infinite scrolling state from here
  // final ScrollController _scrollController = ScrollController();
  // bool _hasMoreData = true;
  // bool _isLoadingMore = false;
  @override
  void initState() {
    super.initState();
    // Remove infinite scrolling listener from here
    // _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Remove infinite scrolling controller disposal from here
    // _scrollController.dispose();
    super.dispose();
  }

  // Remove infinite scrolling logic from here
  // Future<void> _onScroll() async {
  //   if (!_isLoadingMore &&
  //       _hasMoreData &&
  //       _scrollController.position.pixels >=
  //           _scrollController.position.maxScrollExtent * 0.8) {
  //     _isLoadingMore = true;
  //     final hasMore =
  //         await Provider.of<NotificationProvider>(
  //           context,
  //           listen: false,
  //         ).loadMoreNotifications();

  //     setState(() {
  //       _hasMoreData = hasMore;
  //       _isLoadingMore = false;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings page
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              _confirmClearNotifications(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Notification History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          // Show permission request if not listening
          if (!provider.isListening) {
            // Use the new PermissionRequestWidget
            return const PermissionRequestWidget();
          }

          // Get grouped notifications
          final groupedNotifications = provider.getNotificationsByApp();

          // Show empty state if no notifications
          if (groupedNotifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off,
              title: 'No notifications yet',
              message: 'Notifications will appear here as they arrive',
            );
          }

          // Use the new NotificationListView
          return const NotificationListView();
        },
      ),
      floatingActionButton: Builder(
        builder:
            (context) => FloatingActionButton.extended(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Send Test Notification'),
              onPressed: () async {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue[800]!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Sending test notification...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.blue[50],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blue[200]!, width: 1),
                    ),
                    margin: const EdgeInsets.all(16),
                    elevation: 2,
                  ),
                );

                try {
                  await Provider.of<NotificationProvider>(
                    context,
                    listen: false,
                  ).sendTestNotification(
                    title: 'Test Notification',
                    body:
                        'This is a test notification sent from Notification Hub',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green[800],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Test notification sent successfully!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 3),
                        backgroundColor: Colors.green[50],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.green[200]!, width: 1),
                        ),
                        margin: const EdgeInsets.all(16),
                        elevation: 2,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    String errorMessage = 'Failed to send test notification';

                    // Provide more specific error messages
                    if (e.toString().contains('POST_NOTIFICATIONS')) {
                      errorMessage =
                          'Please grant notification permission in Settings';
                    } else if (e.toString().contains('permission')) {
                      errorMessage = 'Notification permission required';
                    } else if (e.toString().contains('SecurityException')) {
                      errorMessage = 'Permission denied - check app settings';
                    } else {
                      errorMessage = 'Error: ${e.toString()}';
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red[800],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 5),
                        backgroundColor: Colors.red[50],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red[200]!, width: 1),
                        ),
                        margin: const EdgeInsets.all(16),
                        elevation: 2,
                        action: SnackBarAction(
                          label: 'Settings',
                          textColor: Colors.red[800],
                          onPressed: () {
                            // Try to open app settings
                            debugPrint(
                              'Opening app settings for notification permission',
                            );
                          },
                        ),
                      ),
                    );
                  }
                }
              },
            ),
      ),
    );
  }

  // Remove extracted widget build methods
  // Widget _buildPermissionRequest(NotificationProvider provider) {...}
  // Widget _buildNotificationList(...) {...}
  // Widget _buildDefaultIcon() {...}
  // Widget _buildNotificationCard({...}) {...}
  // Widget _buildNotificationItem(AppNotification notification) {...}

  void _confirmClearNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<NotificationProvider>(
                    context,
                    listen: false,
                  ).clearAllNotifications();
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }
}
