package com.qbrahym.vshapeapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires the "it is time for <prayer>" notification.
 *
 * Deliberately does NOT re-arm anything: unlike the daily reminders, a prayer
 * time is different every day, and the 7-day batch that Dart pushed already
 * covers the horizon. [BootReceiver] re-arms the batch after a reboot.
 */
class PrayerReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "V-System"
        val body = intent.getStringExtra("body") ?: ""

        try {
            Prayers.createChannel(ctx)
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val content = launch?.let {
                it.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                android.app.PendingIntent.getActivity(
                    ctx, 1000 + id, it,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE
                )
            }

            val n = androidx.core.app.NotificationCompat.Builder(ctx, Prayers.CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(androidx.core.app.NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                .setCategory(androidx.core.app.NotificationCompat.CATEGORY_EVENT)
                .setAutoCancel(true)
                .setContentIntent(content)
                .build()

            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE)
                as android.app.NotificationManager
            nm.notify(10000 + id, n)
        } catch (e: Exception) {
        }
    }
}
