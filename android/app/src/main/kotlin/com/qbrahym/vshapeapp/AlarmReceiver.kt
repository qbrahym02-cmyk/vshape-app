package com.qbrahym.vshapeapp

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/** Shows a reminder and re-arms the same alarm for tomorrow. */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "V-System"
        val body = intent.getStringExtra("body") ?: ""
        val hour = intent.getIntExtra("hour", -1)
        val minute = intent.getIntExtra("minute", 0)

        Alarms.createChannel(ctx)
        show(ctx, id, title, body)

        // re-arm for the next day (keeps the reminder daily)
        if (hour in 0..23) {
            val spec = AlarmSpec(id, hour, minute, title, body)
            try {
                val am = ctx.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                val pi = Alarms.pendingIntent(ctx, spec)
                val trigger = Alarms.nextTrigger(hour, minute)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, trigger, pi)
                } else {
                    am.set(android.app.AlarmManager.RTC_WAKEUP, trigger, pi)
                }
            } catch (e: Exception) {
            }
        }
    }

    private fun show(ctx: Context, id: Int, title: String, body: String) {
        try {
            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            val content = if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                PendingIntent.getActivity(
                    ctx, 1000 + id, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else null

            val n = NotificationCompat.Builder(ctx, Alarms.CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(content)
                .build()

            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(2000 + id, n)
        } catch (e: Exception) {
        }
    }
}
