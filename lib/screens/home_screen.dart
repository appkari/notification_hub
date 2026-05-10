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
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Notifications'),
              onPressed: () => _confirmClearNotifications(context),
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
