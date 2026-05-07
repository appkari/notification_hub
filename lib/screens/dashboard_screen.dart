import 'package:flutter/material.dart'
    show
        AppBar,
        BorderRadius,
        BoxDecoration,
        BuildContext,
        Card,
        Center,
        CircleAvatar,
        Colors,
        Column,
        Container,
        CrossAxisAlignment,
        EdgeInsets,
        Expanded,
        FontWeight,
        ListTile,
        ListView,
        MainAxisAlignment,
        MemoryImage,
        Padding,
        Radius,
        Row,
        Scaffold,
        SingleTickerProviderStateMixin,
        SizedBox,
        State,
        StatefulWidget,
        Tab,
        TabBar,
        TabBarView,
        TabController,
        Text,
        TextStyle,
        Theme,
        Widget;
import 'package:provider/provider.dart' show Consumer; // Already uses show
import 'package:intl/intl.dart' show DateFormat; // Already uses show
import 'dart:convert' show base64Decode; // Already uses show
import '../providers/notification_provider.dart'
    show NotificationProvider; // Already uses show
import '../models/notification_model.dart'
    show AppNotification; // Already uses show

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'By App'),
            Tab(text: 'Timeline'),
          ],
        ),
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final notifications =
              provider.notifications.where((n) => !n.isRemoved).toList();

          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notification data available to analyze'),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(notifications),
              _buildByAppTab(notifications),
              _buildTimelineTab(notifications),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewTab(List<AppNotification> notifications) {
    // Calculate stats
    final int totalNotifications = notifications.length;
    final appSet = <String>{};
    final todayCount =
        notifications
            .where(
              (n) => n.timestamp.isAfter(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            )
            .length;

    for (final notification in notifications) {
      appSet.add(notification.appName);
    }

    // Get most active app
    final appCounts = <String, int>{};
    for (final notification in notifications) {
      appCounts[notification.appName] =
          (appCounts[notification.appName] ?? 0) + 1;
    }

    String mostActiveApp = 'None';
    int mostActiveCount = 0;

    appCounts.forEach((app, count) {
      if (count > mostActiveCount) {
        mostActiveCount = count;
        mostActiveApp = app;
      }
    });

    // Average notifications per day
    final firstNotifDate = notifications
        .map((n) => n.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final days = DateTime.now().difference(firstNotifDate).inHours / 24;
    final avgPerDay =
        days > 0 ? (totalNotifications / days).toStringAsFixed(1) : 'N/A';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildStatCard('Total Notifications', totalNotifications.toString()),
          _buildStatCard('Apps', appSet.length.toString()),
          _buildStatCard('Today', todayCount.toString()),
          _buildStatCard(
            'Most Active App',
            '$mostActiveApp ($mostActiveCount)',
          ),
          _buildStatCard('Average Daily', avgPerDay),
        ],
      ),
    );
  }

  Widget _buildByAppTab(List<AppNotification> notifications) {
    // Group notifications by app
    final appCounts = <String, int>{};
    final appLatest = <String, DateTime>{};

    for (final notification in notifications) {
      appCounts[notification.appName] =
          (appCounts[notification.appName] ?? 0) + 1;

      final currentLatest = appLatest[notification.appName];
      if (currentLatest == null ||
          notification.timestamp.isAfter(currentLatest)) {
        appLatest[notification.appName] = notification.timestamp;
      }
    }

    // Sort apps by notification count (descending)
    final apps =
        appCounts.keys.toList()
          ..sort((a, b) => appCounts[b]!.compareTo(appCounts[a]!));

    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final count = appCounts[app]!;
        final latest = appLatest[app]!;
        final timeAgo = _getTimeAgo(latest);

        // Try to find a notification from this app that might have an icon
        String? iconData;
        for (final notification in notifications) {
          if (notification.appName == app &&
              notification.iconData != null &&
              notification.iconData!.isNotEmpty) {
            iconData = notification.iconData;
            break;
          }
        }

        // Prepare the avatar widget
        Widget avatarWidget;
        if (iconData != null) {
          try {
            final iconBytes = base64Decode(iconData);
            avatarWidget = CircleAvatar(
              backgroundImage: MemoryImage(iconBytes),
              backgroundColor: Colors.transparent,
            );
          } catch (e) {
            avatarWidget = CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(app[0].toUpperCase()),
            );
          }
        } else {
          avatarWidget = CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(app[0].toUpperCase()),
          );
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: avatarWidget,
            title: Text(app),
            subtitle: Text('Last notification: $timeAgo'),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTab(List<AppNotification> notifications) {
    // Group notifications by day
    final dateFormat = DateFormat('MMMM d, yyyy');
    final groupedByDay = <String, List<AppNotification>>{};

    for (final notification in notifications) {
      final dateKey = dateFormat.format(notification.timestamp);
      if (!groupedByDay.containsKey(dateKey)) {
        groupedByDay[dateKey] = [];
      }
      groupedByDay[dateKey]!.add(notification);
    }

    // Sort dates in descending order
    final sortedDates =
        groupedByDay.keys.toList()
          ..sort((a, b) => dateFormat.parse(b).compareTo(dateFormat.parse(a)));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dayNotifications = groupedByDay[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: ${dayNotifications.length} notifications'),
                  const SizedBox(height: 8),
                  _buildTimeDistributionChart(dayNotifications),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTimeDistributionChart(List<AppNotification> notifications) {
    // Group notifications by hour
    final hourCounts = List<int>.filled(24, 0);

    for (final notification in notifications) {
      final hour = notification.timestamp.hour;
      hourCounts[hour]++;
    }

    // Find max count for scaling
    final maxCount = hourCounts.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 100,
      child: Row(
        children: List.generate(24, (hour) {
          final count = hourCounts[hour];
          final height = maxCount > 0 ? (count / maxCount) * 80 : 0.0;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hour.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
