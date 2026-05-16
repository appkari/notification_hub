package `in`.appkari.notihub

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class NotiHubBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("NotiHubBootReceiver", "BOOT_COMPLETED received")
            if (!isNotificationListenerEnabled(context)) {
                Log.d("NotiHubBootReceiver", "Notification listener not enabled. Prompting user.")
                showEnableNotificationListenerNotification(context)
            } else {
                if (NotiHubKeepaliveService.wasListeningEnabled(context)) {
                    Log.d("NotiHubBootReceiver", "Notification listener is enabled and listening was active before reboot.")
                    NotiHubKeepaliveService.start(context)
                } else {
                    Log.d("NotiHubBootReceiver", "Skipping keepalive start: listening was not active before reboot.")
                }
            }
        }
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val packageName = context.packageName
        val flat = android.provider.Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        )
        return flat?.contains(packageName) ?: false
    }

    private fun showEnableNotificationListenerNotification(context: Context) {
        val channelId = "notihub_boot_channel"
        val channelName = "Notification Hub Boot Channel"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(channelId, channelName, android.app.NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }
        val intent = Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        val pendingIntent = android.app.PendingIntent.getActivity(
            context,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.app.PendingIntent.FLAG_IMMUTABLE else 0
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, channelId)
        } else {
            android.app.Notification.Builder(context)
        }
        builder.setContentTitle("Enable Notification Access")
            .setContentText("Tap to re-enable Notification Hub access after reboot.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
        notificationManager.notify(2001, builder.build())
    }
}
