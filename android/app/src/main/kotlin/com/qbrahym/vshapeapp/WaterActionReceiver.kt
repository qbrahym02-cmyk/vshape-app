package com.qbrahym.vshapeapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * "+250 / +500 ml" tapped on the home-screen widget.
 *
 * The water counters live in the shared_preferences file the Flutter app uses
 * (`FlutterSharedPreferences`, keys prefixed with `flutter.`), so writing here
 * is exactly like a tap inside the app - the numbers show up the next time the
 * app is opened, and the widget refreshes immediately.
 */
class WaterActionReceiver : BroadcastReceiver() {

    override fun onReceive(ctx: Context, intent: Intent) {
        val delta = intent.getIntExtra("delta", 0)
        if (delta == 0) return
        try {
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = "flutter.w_$today"
            val before = when (val raw = prefs.all[key]) {
                is Long -> raw.toInt()
                is Int -> raw
                is String -> raw.toIntOrNull() ?: 0
                else -> 0
            }
            val after = (before + delta).coerceIn(0, 20000)
            prefs.edit().putLong(key, after.toLong()).commit()
            HomeWidget.applyWaterDelta(ctx, after)
        } catch (e: Exception) {
            // never let a widget tap crash the launcher
        }
    }
}
