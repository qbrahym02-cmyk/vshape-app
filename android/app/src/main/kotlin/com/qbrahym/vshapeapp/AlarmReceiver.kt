package com.qbrahym.vshapeapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Shows a reminder and re-arms the same alarm for the next day.
 *
 * The re-arm goes through [Alarms.schedule] so it uses the exact same
 * (exact-when-allowed, inexact as a fallback) policy as the first scheduling.
 * Re-arming with a plain inexact alarm - as an older build did - made the
 * reminder drift later and later on Doze-heavy phones.
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: "V-System"
        val body = intent.getStringExtra("body") ?: ""
        val hour = intent.getIntExtra("hour", -1)
        val minute = intent.getIntExtra("minute", 0)

        try {
            Alarms.notifyNow(ctx, 2000 + id, title, body)
        } catch (e: Exception) {
        }

        if (hour in 0..23) {
            try {
                Alarms.schedule(ctx, AlarmSpec(id, hour, minute, title, body))
            } catch (e: Exception) {
            }
        }
    }
}
