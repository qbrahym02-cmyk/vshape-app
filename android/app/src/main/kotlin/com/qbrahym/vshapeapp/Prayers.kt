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

/**
 * One-shot prayer-time alarm at an exact epoch timestamp.
 *
 * Unlike [AlarmSpec] (daily water/workout/sleep reminders that re-arm
 * themselves for the next day), a prayer time is different every day, so the
 * Dart side sends a batch computed for the next 7 days and re-sends it on
 * every app open, app update and reboot. Nothing here ever re-arms by
 * itself - that is by design, the batch already covers the horizon.
 */
data class PrayerSpec(
    val id: Int,
    val at: Long,
    val title: String,
    val body: String
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("at", at)
        put("title", title)
        put("body", body)
    }

    companion object {
        fun fromJson(o: JSONObject) = PrayerSpec(
            id = o.optInt("id", o.hashCode()),
            at = o.optLong("at", 0L),
            title = o.optString("title", "V-System"),
            body = o.optString("body", "")
        )
    }
}

/**
 * Schedules the prayer-time notification batch and owns its notification
 * channel (kept separate from the reminders channel so the user can silence
 * prayers without losing water reminders, or vice versa).
 */
object Prayers {

    private const val PREFS = "vshape_prayers"
    private const val KEY = "prayers_json"
    const val CHANNEL_ID = "vshape_prayers"

    fun createChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    CHANNEL_ID,
                    "V-System prayer times",
                    NotificationManager.IMPORTANCE_HIGH
                )
                ch.description = "Alert when a prayer time enters"
                ch.enableVibration(true)
                nm.createNotificationChannel(ch)
            }
        }
    }

    fun save(ctx: Context, list: List<PrayerSpec>) {
        val arr = JSONArray()
        for (p in list) arr.put(p.toJson())
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }

    fun load(ctx: Context): List<PrayerSpec> {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { PrayerSpec.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun pendingIntent(ctx: Context, spec: PrayerSpec): PendingIntent {
        val i = Intent(ctx, PrayerReceiver::class.java).apply {
            putExtra("id", spec.id)
            putExtra("title", spec.title)
            putExtra("body", spec.body)
        }
        // 10000+ offset keeps request codes clear of the AlarmManager reminder
        // intents, which use the raw 100+ ids.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(ctx, 10000 + spec.id, i, flags)
    }

    /**
     * Replaces the whole batch: cancels every previously saved alarm, stores
     * the new list and arms everything that is still in the future.
     * Returns how many alarms were armed.
     */
    fun scheduleBatch(ctx: Context, list: List<Map<String, Any?>>): Int {
        createChannel(ctx)
        cancelAll(ctx)
        val specs = list.mapNotNull { m ->
            try {
                PrayerSpec(
                    id = (m["id"] as? Number)?.toInt() ?: return@mapNotNull null,
                    at = (m["at"] as? Number)?.toLong() ?: return@mapNotNull null,
                    title = m["title"] as? String ?: "V-System",
                    body = m["body"] as? String ?: ""
                )
            } catch (e: Exception) {
                null
            }
        }
        save(ctx, specs)
        return scheduleAll(ctx)
    }

    /** Re-arms every saved alarm that is still in the future (boot / update). */
    fun scheduleAll(ctx: Context): Int {
        createChannel(ctx)
        val now = System.currentTimeMillis()
        var n = 0
        for (spec in load(ctx)) {
            if (spec.at <= now) continue
            if (scheduleOne(ctx, spec)) n++
        }
        return n
    }

    /**
     * Same exactness policy as [Alarms.schedule]: exact-and-allow-while-idle
     * whenever the device permits it, inexact fallback otherwise.
     */
    fun scheduleOne(ctx: Context, spec: PrayerSpec): Boolean {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingIntent(ctx, spec)
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        if (canExact) {
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, spec.at, pi)
                return true
            } catch (e: Exception) {
                // fall through to the inexact variants
            }
        }
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, spec.at, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, spec.at, pi)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Cancels every saved alarm and clears the store. */
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
