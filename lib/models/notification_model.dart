// No imports needed for this model file

class AppNotification {
  final String id;
  final String packageName;
  final String appName;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? iconData; // Can be a Base64 string representing the app icon
  final bool isRemoved;
  final String? key; // Android notification key for system tray removal
  final bool hasContentIntent; // Whether the notification has a specific action
  final String? channelId;
  final String? channelName;

  AppNotification({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.body,
    required this.timestamp,
    this.iconData,
    this.isRemoved = false,
    this.key,
    this.hasContentIntent = false,
    this.channelId,
    this.channelName,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      packageName: map['packageName'] ?? '',
      appName: map['appName'] ?? 'Unknown App',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      iconData: map['iconData'],
      isRemoved: map['isRemoved'] ?? false,
      key: map['key'],
      hasContentIntent: map['hasContentIntent'] ?? false,
      channelId: map['channelId']?.toString(),
      channelName: map['channelName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'title': title,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'iconData': iconData,
      'isRemoved': isRemoved,
      'key': key,
      'hasContentIntent': hasContentIntent,
      'channelId': channelId,
      'channelName': channelName,
    };
  }

  AppNotification copyWith({
    String? id,
    String? packageName,
    String? appName,
    String? title,
    String? body,
    DateTime? timestamp,
    String? iconData,
    bool? isRemoved,
    String? key,
    bool? hasContentIntent,
    String? channelId,
    String? channelName,
  }) {
    return AppNotification(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      iconData: iconData ?? this.iconData,
      isRemoved: isRemoved ?? this.isRemoved,
      key: key ?? this.key,
      hasContentIntent: hasContentIntent ?? this.hasContentIntent,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
    );
  }
}

class NotificationChannelInfo {
  const NotificationChannelInfo({
    required this.packageName,
    required this.appName,
    required this.channelId,
    required this.channelName,
    required this.notificationCount,
    this.iconData,
  });

  final String packageName;
  final String appName;
  final String channelId;
  final String channelName;
  final int notificationCount;
  final String? iconData;

  String get storageKey => '$packageName|$channelId';
}
