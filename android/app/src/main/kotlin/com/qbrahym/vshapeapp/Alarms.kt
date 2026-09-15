package com.qbrahym.vshapeapp

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

data class AlarmSpec(
    val id: Int,
    val hour: Int,
    val minute: Int,
    val title: String,
    val body: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("hour", hour)
        put("minute", minute)
        put("title", title)
        put("body", body)
    }

    fun toMap(): Map<String, Any> = mapOf(
        "id" to id, "hour" to hour, "minute" to minute, "title" to title, "body" to body
    )

    companion object {
        fun fromJson(o: JSONObject) = AlarmSpec(
            id = o.optInt("id", o.hashCode()),
            hour = (o.optInt("hour", 8)).coerceIn(0, 23),
            minute = (o.optInt("minute", 0)).coerceIn(0, 59),
            title = o.optString("title", "V-System"),
            body = o.optString("body", "")
        )
    }
}

/**
 * Persists the reminder list coming from Flutter (which itself comes from the
 * remotely-updatable content file) and registers daily AlarmManager alarms.
 */
object Alarms {

    private const val PREFS = "vshape_alarms"
    private const val KEY = "alarms_json"
    const val CHANNEL_ID = "vshape_reminders"

    fun createChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "V-System reminders",
                    NotificationManager.IMPORTANCE_HIGH
                )
                ch.description = "Water, workout and sleep reminders"
                ch.enableVibration(true)
                nm.createNotificationChannel(ch)
            }
        }
    }

    fun save(ctx: Context, list: List<Map<String, Any?>>) {
        val arr = JSONArray()
        for (m in list) {
            val o = JSONObject()
            o.put("id", (m["id"] as? Number)?.toInt() ?: m.hashCode())
            o.put("hour", (m["hour"] as? Number)?.toInt() ?: 8)
            o.put("minute", (m["minute"] as? Number)?.toInt() ?: 0)
            o.put("title", (m["title"] as? String) ?: "V-System")
            o.put("body", (m["body"] as? String) ?: "")
            arr.put(o)
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }

    fun load(ctx: Context): List<AlarmSpec> {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { AlarmSpec.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun pendingIntent(ctx: Context, spec: AlarmSpec): PendingIntent {
        val i = Intent(ctx, AlarmReceiver::class.java).apply {
            putExtra("id", spec.id)
            putExtra("title", spec.title)
            putExtra("body", spec.body)
            putExtra("hour", spec.hour)
            putExtra("minute", spec.minute)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(ctx, spec.id, i, flags)
    }

    /** Next occurrence of hour:minute from now. */
    fun nextTrigger(hour: Int, minute: Int): Long {
        val now = java.util.Calendar.getInstance()
        val next = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }
        if (!next.after(now)) next.add(java.util.Calendar.DAY_OF_YEAR, 1)
        return next.timeInMillis
    }

    /** Schedules every saved alarm. Returns how many were scheduled. */
    fun scheduleAll(ctx: Context): Int {
        createChannel(ctx)
        var n = 0
        for (spec in load(ctx)) n += if (schedule(ctx, spec)) 1 else 0
        return n
    }

    /**
     * Registers one alarm, as exactly as this device allows.
     *
     * `setExactAndAllowWhileIdle` is used whenever the app is permitted to, so
     * a reminder keeps firing at 17:25 instead of sliding into a Doze window.
     * Every exact call can throw (SecurityException on Android 12+ when the
     * "alarms & reminders" permission was revoked), hence the inexact fallback.
     */
    fun schedule(ctx: Context, spec: AlarmSpec, triggerAt: Long = nextTrigger(spec.hour, spec.minute)): Boolean {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingIntent(ctx, spec)
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        if (canExact) {
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
                return true
            } catch (e: Exception) {
                // fall through to the inexact variants
            }
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** One-off notification from Flutter (the rest timer uses this). */
    fun notifyNow(ctx: Context, id: Int, title: String, body: String) {
        createChannel(ctx)
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val content = if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            PendingIntent.getActivity(
                ctx, 1000 + id, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val n = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setAutoCancel(true)
            .setContentIntent(content)
            .build()

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(id, n)
    }

    fun vibrate(ctx: Context, ms: Long) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val v = ctx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                v?.vibrate(
                    android.os.VibrationEffect.createOneShot(
                        ms, android.os.VibrationEffect.DEFAULT_AMPLITUDE
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                val v = ctx.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                @Suppress("DEPRECATION")
                v?.vibrate(ms)
            }
        } catch (e: Exception) {
        }
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (spec in load(ctx)) {
            try {
                am.cancel(pendingIntent(ctx, spec))
            } catch (e: Exception) {
            }
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }
}
