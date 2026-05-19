import 'package:flutter/material.dart'
    show
        AlertDialog,
        AppBar,
        BuildContext,
        Center,
        CircularProgressIndicator,
        Colors,
        FloatingActionButton,
        FloatingActionButtonLocation,
        Icon,
        IconButton,
        Icons,
        MaterialPageRoute,
        Navigator,
        Scaffold,
        ScaffoldMessenger,
        SnackBar,
        SnackBarAction,
        State,
        StatefulWidget,
        Text,
        TextButton,
        Widget,
        showDialog;
import 'package:provider/provider.dart' show Consumer;

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

  Future<void> _confirmClearAllNotifications(
    BuildContext context,
    NotificationProvider provider,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Clear All'),
              ),
            ],
          ),
    );

    if (shouldClear != true || !mounted) return;

    final cleared = await provider.clearAllNotifications();

    if (!mounted) return;
    ScaffoldMessenger.of(this.context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('${cleared.length} notifications cleared'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await provider.restoreNotifications(cleared);
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        final groupedNotifications = provider.getNotificationsByApp();
        final showClearAllButton =
            provider.isListening && groupedNotifications.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notification Hub'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
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
          floatingActionButton:
              showClearAllButton
                  ? FloatingActionButton.extended(
                    onPressed: () {
                      _confirmClearAllNotifications(context, provider);
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear All'),
                  )
                  : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          body: () {
            if (!provider.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.initError != null) {
              return Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not start',
                  message: provider.initError!,
                ),
              );
            }

            if (!provider.isListening) {
              return const PermissionRequestWidget();
            }

            if (groupedNotifications.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_off,
                title: 'No notifications yet',
                message: 'Notifications will appear here as they arrive',
              );
            }

            return const NotificationListView();
          }(),
        );
      },
    );
  }

  // Remove extracted widget build methods
  // Widget _buildPermissionRequest(NotificationProvider provider) {...}
  // Widget _buildNotificationList(...) {...}
  // Widget _buildDefaultIcon() {...}
  // Widget _buildNotificationCard({...}) {...}
  // Widget _buildNotificationItem(AppNotification notification) {...}
}
