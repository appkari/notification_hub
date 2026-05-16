package `in`.appkari.notihub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * A minimal foreground service whose only purpose is to keep the app process alive.
 *
 * Android can kill background processes under memory pressure. By running a foreground
 * service with a persistent (but silent, low-priority) notification, we prevent the OS
 * from terminating the process, which would otherwise also kill the
 * [NotiHubNotificationService].
 *
 * Lifecycle:
 * - Started when Flutter enables listening.
 * - Stopped when Flutter disables listening.
 * - Re-started after boot only if listening was enabled before reboot.
 */
class NotiHubKeepaliveService : Service() {

    companion object {
        private const val TAG = "NotiHubKeepalive"
        private const val CHANNEL_ID = "notihub_keepalive_channel"
        private const val NOTIFICATION_ID = 9998
        private const val PREFS_NAME = "notihub_prefs"
        private const val PREF_LISTENING_ENABLED = "pref_listening_enabled"

        fun start(context: Context) {
            val intent = Intent(context, NotiHubKeepaliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, NotiHubKeepaliveService::class.java))
        }

        fun setListeningEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PREF_LISTENING_ENABLED, enabled)
                .apply()
        }

        fun wasListeningEnabled(context: Context): Boolean {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(PREF_LISTENING_ENABLED, false)
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Keepalive service created")
        startForegroundWithNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Re-post the foreground notification in case the service is restarted
        startForegroundWithNotification()
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "Keepalive service destroyed")
        super.onDestroy()
    }

    private fun startForegroundWithNotification() {
        ensureChannel()

        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 0, tapIntent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setContentTitle("Notification Hub")
            .setContentText("Listening for notifications")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setVisibility(Notification.VISIBILITY_SECRET)
        }

        startForeground(NOTIFICATION_ID, builder.build())
        Log.d(TAG, "Foreground notification posted")
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "Notification Hub Active",
                    NotificationManager.IMPORTANCE_MIN, // Silent, no heads-up
                ).apply {
                    description = "Keeps the notification listener running in the background"
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                    setSound(null, null)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }
}
