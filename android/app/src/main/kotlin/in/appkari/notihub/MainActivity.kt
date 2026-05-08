package `in`.appkari.notihub

import `in`.appkari.notihub.NotiHubNotificationService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.content.Intent
import android.net.Uri
import android.app.Notification
import android.app.NotificationChannel
import android.content.pm.PackageManager
import android.util.Log
import java.util.Random
import android.app.PendingIntent

class MainActivity : FlutterActivity() {
    private val CHANNEL = "notification_capture"
    private val NOTIFICATION_LISTENER_SETTINGS = "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
    private val POST_NOTIFICATIONS_REQUEST_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        NotiHubNotificationService.channel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "removeNotification" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        NotiHubNotificationService.removeNotificationByKey(key)
                        result.success(null)
                    } else {
                        result.error("INVALID_KEY", "Key is null", null)
                    }
                }
                "updateRemoveSystemTraySetting" -> {
                    // Allows Flutter to control whether notifications are removed from the system tray
                    val remove = call.argument<Boolean>("remove")
                    if (remove != null) {
                        NotiHubNotificationService.shouldRemoveSystemTrayNotification = remove
                        if (remove) {
                            // When enabling, clear all notifications from system tray immediately
                            NotiHubNotificationService.clearAllNotifications()
                        }
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Argument 'remove' is null", null)
                    }
                }
                "requestPermission" -> {
                    // Open notification listener settings if not enabled
                    if (!isNotificationServiceEnabled()) {
                        val intent = Intent(NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        // Can't know if granted immediately, return false for now
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "isPermissionGranted" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "startListening" -> {
                    NotiHubNotificationService.isListening = true
                    result.success(true)
                }
                "stopListening" -> {
                    NotiHubNotificationService.isListening = false
                    result.success(true)
                }
                "sendTestNotification" -> {
                    val title = call.argument<String>("title") ?: "Test Notification"
                    val body = call.argument<String>("body") ?: "This is a test notification"
                    try {
                        val success = sendTestNotification(title, body)
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error sending test notification: ${e.message}")
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }
                "clearAllNotifications" -> {
                    NotiHubNotificationService.clearAllNotifications()
                    result.success(null)
                }
                "acknowledgeAndRemoveNotification" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        NotiHubNotificationService.removeNotificationByKey(key)
                        result.success(null)
                    } else {
                        result.error("INVALID_KEY", "Key is null", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val success = launchApp(packageName)
                        result.success(success)
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                }
                "openAppInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(openAppInfo(packageName))
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                }
                "openAppNotificationSettings" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(openAppNotificationSettings(packageName))
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                }
                "openChannelNotificationSettings" -> {
                    val packageName = call.argument<String>("packageName")
                    val channelId = call.argument<String>("channelId")
                    if (packageName != null && channelId != null) {
                        result.success(openChannelNotificationSettings(packageName, channelId))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name or channel ID is null", null)
                    }
                }
                "executeNotificationAction" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        val success = NotiHubNotificationService.executeNotificationAction(key)
                        result.success(success)
                    } else {
                        result.error("INVALID_KEY", "Notification key is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val packageName = packageName
        val flat = android.provider.Settings.Secure.getString(contentResolver,
            "enabled_notification_listeners")
        return flat?.contains(packageName) ?: false
    }

    private fun requestNotificationListenerPermission() {
        if (!isNotificationServiceEnabled()) {
            val intent = Intent(NOTIFICATION_LISTENER_SETTINGS)
            startActivity(intent)
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Request notification listener permission
        requestNotificationListenerPermission()
        // Request POST_NOTIFICATIONS permission for Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), POST_NOTIFICATIONS_REQUEST_CODE)
            }
        }
        // Prompt user to exclude from battery optimizations"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:" + packageName)
                startActivity(intent)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            POST_NOTIFICATIONS_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Log.d("MainActivity", "POST_NOTIFICATIONS permission granted")
                } else {
                    Log.w("MainActivity", "POST_NOTIFICATIONS permission denied")
                }
            }
        }
    }

    private fun launchApp(packageName: String): Boolean {
        Log.d("MainActivity", "=== LAUNCHING APP ===")
        Log.d("MainActivity", "Package name: $packageName")
        return try {
            val packageManager = packageManager
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            Log.d("MainActivity", "Launch intent found: ${intent != null}")
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                Log.d("MainActivity", "Starting activity with intent: $intent")
                startActivity(intent)
                Log.d("MainActivity", "Successfully launched app: $packageName")
                true
            } else {
                Log.w("MainActivity", "No launch intent found for package: $packageName")
                // Try alternative method - check if app is installed
                try {
                    packageManager.getApplicationInfo(packageName, 0)
                    Log.w("MainActivity", "App $packageName is installed but has no launch intent")
                } catch (e: Exception) {
                    Log.w("MainActivity", "App $packageName is not installed")
                }
                false
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to launch app $packageName: ${e.message}")
            Log.e("MainActivity", "Exception details: ${e.stackTraceToString()}")
            false
        }
    }

    private fun openAppInfo(packageName: String): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open app info for $packageName: ${e.message}")
            false
        }
    }

    private fun openAppNotificationSettings(packageName: String): Boolean {
        return try {
            val intent = Intent().apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra("app_package", packageName)
                putExtra("app_uid", packageManager.getApplicationInfo(packageName, 0).uid)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open notification settings for $packageName: ${e.message}")
            false
        }
    }

    private fun openChannelNotificationSettings(packageName: String, channelId: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                }
                startActivity(intent)
                true
            } else {
                openAppNotificationSettings(packageName)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open channel settings for $packageName/$channelId: ${e.message}")
            false
        }
    }

    private fun sendTestNotification(title: String, body: String): Boolean {
        Log.d("MainActivity", "=== SENDING TEST NOTIFICATION ===")
        Log.d("MainActivity", "Title: $title")
        Log.d("MainActivity", "Body: $body")
        
        // Check POST_NOTIFICATIONS permission for Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
            Log.d("MainActivity", "POST_NOTIFICATIONS permission granted: $granted")
            if (!granted) {
                Log.e("MainActivity", "POST_NOTIFICATIONS permission not granted - cannot send notification")
                throw SecurityException("POST_NOTIFICATIONS permission not granted")
            }
        }
        
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Check if notification manager is available
            if (notificationManager == null) {
                Log.e("MainActivity", "NotificationManager is null")
                throw IllegalStateException("NotificationManager not available")
            }
            
            val channelId = "test_channel"
            val channelName = "Test Channel"
            
            // Create notification channel for Android 8.0+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val existingChannel = notificationManager.getNotificationChannel(channelId)
                if (existingChannel == null) {
                    val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
                    channel.description = "Channel for test notifications"
                    channel.enableLights(true)
                    channel.enableVibration(true)
                    notificationManager.createNotificationChannel(channel)
                    Log.d("MainActivity", "Created notification channel: $channelId")
                } else {
                    Log.d("MainActivity", "Notification channel already exists: $channelId")
                }
            }
            
            // Create PendingIntent to open this app when notification is tapped
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("from_test_notification", true)
            }
            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            } else {
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
            }
            
            // Build the notification with clear test identifier
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, channelId)
            } else {
                Notification.Builder(this)
            }
            
            // Ensure title has "Test" in it to pass through the filter
            val testTitle = if (!title.lowercase().contains("test")) {
                "Test: $title"
            } else {
                title
            }
            
            builder.setContentTitle(testTitle)
                .setContentText(body)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setAutoCancel(true)
                .setPriority(Notification.PRIORITY_HIGH)
                .setCategory(Notification.CATEGORY_MESSAGE) // Mark as a message to distinguish from system notifications
                .setContentIntent(pendingIntent) // Add tap action to open the app
            
            // Set additional properties for better visibility
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setVisibility(Notification.VISIBILITY_PUBLIC)
            }
            
            // Add extra data to help identify this as a test notification
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                val extras = android.os.Bundle()
                extras.putString("notification_type", "test")
                extras.putBoolean("is_test_notification", true)
                builder.setExtras(extras)
            }
            
            val notification = builder.build()
            val notificationId = System.currentTimeMillis().toInt() // Use timestamp as ID
            
            Log.d("MainActivity", "Attempting to notify with ID: $notificationId")
            Log.d("MainActivity", "Test notification title: $testTitle")
            Log.d("MainActivity", "Test notification has PendingIntent: ${pendingIntent != null}")
            notificationManager.notify(notificationId, notification)
            Log.d("MainActivity", "=== TEST NOTIFICATION SENT SUCCESSFULLY ===")
            
            return true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to send test notification: ${e.message}")
            Log.e("MainActivity", "Exception type: ${e.javaClass.simpleName}")
            e.printStackTrace()
            throw e
        }
    }
}
