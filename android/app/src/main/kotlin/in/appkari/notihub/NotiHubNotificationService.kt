package `in`.appkari.notihub

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import android.util.Log
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build.VERSION_CODES

class NotiHubNotificationService : NotificationListenerService() {
    companion object {
        var channel: MethodChannel? = null
        var instance: NotiHubNotificationService? = null
        var shouldRemoveSystemTrayNotification: Boolean = false // Default to false (keep)
        var isListening: Boolean = false // Controls forwarding to Flutter
        val programmaticallyRemovedKeys = mutableSetOf<String>()
        // Store PendingIntents by notification key for later execution
        private val pendingIntents = mutableMapOf<String, android.app.PendingIntent?>()

        // Debounce support: pending runnables keyed by notification key
        private val debounceHandler = Handler(Looper.getMainLooper())
        private val pendingRunnables = mutableMapOf<String, Runnable>()
        private val pendingPostedNotifications = mutableMapOf<String, StatusBarNotification>()
        private const val DEBOUNCE_MS = 300L

        fun removeNotificationByKey(key: String) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                programmaticallyRemovedKeys.add(key)
                pendingIntents.remove(key)
                instance?.cancelNotification(key)
            }
        }

        // Only clears notifications from the system tray, not the app's notification list
        fun clearAllNotifications() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Add all keys to programmaticallyRemovedKeys before removal
                instance?.activeNotifications?.forEach { 
                    programmaticallyRemovedKeys.add(it.key)
                    pendingIntents.remove(it.key) // Clean up stored PendingIntents
                }
                instance?.cancelAllNotifications()
            } else {
                instance?.activeNotifications?.forEach { 
                    programmaticallyRemovedKeys.add(it.key)
                    pendingIntents.remove(it.key) // Clean up stored PendingIntents
                }
                instance?.activeNotifications?.forEach { instance?.cancelNotification(it.key) }
            }
        }

        // Execute the original notification's PendingIntent
        fun executeNotificationAction(key: String): Boolean {
            Log.d("NotiHubService", "Attempting to execute notification action for key: $key")
            val pendingIntent = pendingIntents.remove(key)
            return if (pendingIntent != null) {
                try {
                    Log.d("NotiHubService", "PendingIntent found, executing...")
                    pendingIntent.send()
                    Log.d("NotiHubService", "PendingIntent executed successfully for key: $key")
                    true
                } catch (e: Exception) {
                    Log.e("NotiHubService", "Failed to execute notification action for key $key: ${e.message}")
                    Log.e("NotiHubService", "Exception details: ${e.stackTraceToString()}")
                    false
                }
            } else {
                Log.w("NotiHubService", "No PendingIntent found for notification key: $key")
                Log.d("NotiHubService", "Available keys in pendingIntents: ${pendingIntents.keys}")
                false
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("NotiHubService", "Service created")
        instance = this
        // Do NOT start as a foreground service. Let the system manage this service.
    }

    override fun onDestroy() {
        Log.d("NotiHubService", "Service destroyed")
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
        // Send a notification to inform the user
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "notihub_service_channel"
        val channelName = getString(R.string.service_channel_name)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }
        builder.setContentTitle(getString(R.string.service_stopped_title))
            .setContentText(getString(R.string.service_stopped_message))
            .setSmallIcon(android.R.drawable.ic_dialog_alert) // Use a generic system icon for now
            .setAutoCancel(true)
        notificationManager.notify(1001, builder.build())
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        Log.d("NotiHubService", "=== NOTIFICATION RECEIVED ===")
        Log.d("NotiHubService", "Package: ${sbn.packageName}")
        Log.d("NotiHubService", "ID: ${sbn.id}, Tag: ${sbn.tag}, Key: ${sbn.key}")
        Log.d("NotiHubService", "Time: ${System.currentTimeMillis()}")
        if (channel == null) {
            Log.d("NotiHubService", "MethodChannel is null, cannot send to Flutter")
        } else {
            Log.d("NotiHubService", "MethodChannel is set, sending to Flutter")
        }
        if (!isListening) {
            Log.d("NotiHubService", "isListening is false, not forwarding notification to Flutter")
            return
        }

        // Debounce: cancel any pending send for this key and schedule a fresh one.
        // This prevents rapid-fire updates (e.g. download/install progress) from
        // flooding the Flutter side and causing UI jank.
        val notifKey = sbn.key
        pendingPostedNotifications[notifKey] = sbn
        pendingRunnables.remove(notifKey)?.let { debounceHandler.removeCallbacks(it) }
        val runnable = Runnable {
            pendingRunnables.remove(notifKey)
            val latestSbn = pendingPostedNotifications.remove(notifKey) ?: return@Runnable
            forwardPostedNotification(latestSbn)
        }
        pendingRunnables[notifKey] = runnable
        debounceHandler.postDelayed(runnable, DEBOUNCE_MS)
        
        Log.d("NotiHubService", "shouldRemoveSystemTrayNotification: $shouldRemoveSystemTrayNotification")
        // Remove the notification from the system tray if needed and the setting is enabled
        if (shouldRemoveSystemTrayNotification && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val key = sbn.key
            programmaticallyRemovedKeys.add(key)
            cancelNotification(key)
        }
    }

    private fun forwardPostedNotification(sbn: StatusBarNotification) {
        val packageManager = applicationContext.packageManager
        val appName = try {
            val applicationInfo = packageManager.getApplicationInfo(sbn.packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            sbn.packageName
        }

        val extras = sbn.notification.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val channelId = if (Build.VERSION.SDK_INT >= VERSION_CODES.O) {
            sbn.notification.channelId
        } else {
            null
        }
        val channelName = if (Build.VERSION.SDK_INT >= VERSION_CODES.O && channelId != null) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.getNotificationChannel(channelId)?.name?.toString()
        } else {
            null
        }

        val contentIntent = sbn.notification.contentIntent
        pendingIntents[sbn.key] = contentIntent

        var iconData: String? = null
        try {
            val appInfo = packageManager.getApplicationInfo(sbn.packageName, 0)
            val drawable = appInfo.loadIcon(packageManager)
            val bitmap = Bitmap.createBitmap(
                drawable.intrinsicWidth,
                drawable.intrinsicHeight,
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val byteArray = stream.toByteArray()
            iconData = android.util.Base64.encodeToString(byteArray, android.util.Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.e("NotiHubService", "Error getting app icon: " + e.message)
        }

        val notificationData = mutableMapOf<String, Any?>(
            "packageName" to sbn.packageName,
            "appName" to appName,
            "title" to title,
            "body" to text,
            "id" to sbn.id,
            "tag" to sbn.tag,
            "key" to sbn.key,
            "iconData" to iconData,
            "hasContentIntent" to (contentIntent != null),
            "channelId" to channelId,
            "channelName" to channelName
        )

        extras?.keySet()?.forEach { key ->
            extras.get(key)?.let { value ->
                notificationData["extra_$key"] = value.toString()
            }
        }

        channel?.invokeMethod("onNotificationReceived", notificationData)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Note: onNotificationRemoved is called for both user and programmatic removals.
        // Dart side now ignores programmatic removals using a key tracking set.
        Log.d("NotiHubService", "Notification removed: \\${sbn.key}")

        // Cancel any pending debounced post for this key so a stale "new"
        // notification is never forwarded to Flutter after the removal.
        val key = sbn.key
        pendingRunnables.remove(key)?.let { debounceHandler.removeCallbacks(it) }
        pendingPostedNotifications.remove(key)
        val packageManager = applicationContext.packageManager
        val appName = try {
            val applicationInfo = packageManager.getApplicationInfo(sbn.packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            sbn.packageName
        }
        val extras = sbn.notification.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val channelId = if (Build.VERSION.SDK_INT >= VERSION_CODES.O) {
            sbn.notification.channelId
        } else {
            null
        }
        val channelName = if (Build.VERSION.SDK_INT >= VERSION_CODES.O && channelId != null) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.getNotificationChannel(channelId)?.name?.toString()
        } else {
            null
        }
        // Skip icon encoding on removal — the Flutter side already has the
        // icon cached from onNotificationPosted and does not use it from
        // removal events. Encoding a full-resolution PNG here is pure waste.
        val notificationData = mutableMapOf<String, Any?>(
            "packageName" to sbn.packageName,
            "appName" to appName,
            "title" to title,
            "body" to text,
            "id" to sbn.id,
            "tag" to sbn.tag,
            "key" to key,
            "iconData" to null,
            "channelId" to channelId,
            "channelName" to channelName
        )
        extras?.keySet()?.forEach { key ->
            extras.get(key)?.let { value ->
                notificationData["extra_$key"] = value.toString()
            }
        }
        pendingIntents.remove(key)
        if (programmaticallyRemovedKeys.remove(key)) {
            notificationData["programmatic"] = true
        }
        channel?.invokeMethod("onNotificationRemoved", notificationData)
    }
}      
