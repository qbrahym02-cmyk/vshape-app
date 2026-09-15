package com.qbrahym.vshapeapp

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
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
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        var n = 0
        for (spec in load(ctx)) {
            val pi = pendingIntent(ctx, spec)
            val trigger = nextTrigger(spec.hour, spec.minute)
            try {
                val exactOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    am.canScheduleExactAlarms()
                } else true
                if (exactOk && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, trigger, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, trigger, pi)
                }
                n++
            } catch (e: Exception) {
                try {
                    am.set(AlarmManager.RTC_WAKEUP, trigger, pi)
                    n++
                } catch (e2: Exception) {
                    // give up on this one
                }
            }
        }
        return n
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
