package com.qbrahym.vshapeapp

import android.content.Context
import org.json.JSONObject

/**
 * Last snapshot the app pushed for the home-screen widget.
 *
 * The widget renders from this even after a reboot or a launcher restart, and
 * `BootReceiver` re-applies it - so the home screen never shows stale zeroes.
 */
object AppWidgetStore {

    private const val PREFS = "vshape_widget"
    private const val KEY = "data_json"

    fun save(ctx: Context, json: String) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, json).apply()
    }

    fun load(ctx: Context): JSONObject? {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }
}
