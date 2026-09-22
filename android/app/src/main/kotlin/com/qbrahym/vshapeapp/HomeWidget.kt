package com.qbrahym.vshapeapp

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Home-screen widget (classic RemoteViews - no Compose, no Glance, no extra
 * dependencies, so the APK stays small and the build stays light).
 *
 * All the numbers and all the strings arrive pre-formatted from Dart
 * (see lib/services/widget_bridge.dart), which means the widget is bilingual
 * and follows content.json updates without touching this file.
 */
class HomeWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = AppWidgetStore.load(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, data))
        }
    }

    companion object {

        /** True when the user has at least one instance on a home screen. */
        fun isInstalled(ctx: Context): Boolean = try {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, HomeWidget::class.java))
            ids != null && ids.isNotEmpty()
        } catch (e: Exception) {
            false
        }

        /** Re-renders every instance, from [json] when given (otherwise cached). */
        fun updateAll(ctx: Context, json: String? = null) {
            try {
                if (json != null) AppWidgetStore.save(ctx, json)
                val mgr = AppWidgetManager.getInstance(ctx) ?: return
                val ids = mgr.getAppWidgetIds(ComponentName(ctx, HomeWidget::class.java))
                    ?: return
                if (ids.isEmpty()) return
                val data = AppWidgetStore.load(ctx)
                for (id in ids) {
                    try {
                        mgr.updateAppWidget(id, buildViews(ctx, data))
                    } catch (e: Exception) {
                    }
                }
            } catch (e: Exception) {
            }
        }

        private fun buildViews(ctx: Context, d: JSONObject?): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.widget_vsystem)
            val ar = (d?.optString("lang", "ar") ?: "ar") == "ar"

            fun s(key: String, arDefault: String, enDefault: String): String {
                // optString returns "" (not null) for a missing key, so the
                // Kotlin defaults only apply when the value is missing *or* blank.
                val raw = d?.optString(key) ?: ""
                return if (raw.isNotBlank()) raw else if (ar) arDefault else enDefault
            }

            val water = d?.optString("water") ?: "0.0"
            val goal = d?.optString("waterGoal") ?: "3.8"
            val unit = s("waterUnit", "لتر", "L")
            val glasses = d?.optInt("waterGlasses", 0) ?: 0
            val glassesWord = if (ar) "كوب" else "glasses"

            v.setTextViewText(R.id.w_water, "$water / $goal $unit")
            v.setTextViewText(R.id.w_water_sub, "$glasses $glassesWord")
            v.setProgressBar(R.id.w_water_bar, 100, (d?.optInt("waterPct", 0) ?: 0).coerceIn(0, 100), false)

            // Next-prayer row: pre-formatted by Dart, hidden until a city is
            // picked ("prayer" key blank / missing).
            val prayer = d?.optString("prayer") ?: ""
            if (prayer.isNotBlank()) {
                v.setTextViewText(R.id.w_prayer, prayer)
                v.setTextViewText(R.id.w_prayer_left, d?.optString("prayerLeft") ?: "")
                v.setViewVisibility(R.id.w_prayer_row, android.view.View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.w_prayer_row, android.view.View.GONE)
            }

            v.setTextViewText(
                R.id.w_protein,
                "🍗 ${d?.optInt("protein", 0) ?: 0}/${d?.optInt("proteinGoal", 150) ?: 150}${s("proteinUnit", "جم", "g")}"
            )
            v.setTextViewText(
                R.id.w_kcal,
                "🔥 ${d?.optInt("kcal", 0) ?: 0}/${d?.optInt("kcalGoal", 3000) ?: 3000}"
            )
            v.setTextViewText(R.id.w_streak, "${d?.optInt("streak", 0) ?: 0} 🔥")

            val emoji = d?.optString("emoji") ?: "💪"
            val title = d?.optString("workout") ?: if (ar) "افتح التطبيق" else "Open the app"
            v.setTextViewText(R.id.w_workout, "$emoji $title")

            val done = d?.optInt("setsDone", 0) ?: 0
            val total = d?.optInt("setsTotal", 0) ?: 0
            val rest = d?.optBoolean("restDay", false) ?: false
            val pct = if (total <= 0) (if (rest) 100 else 0) else (done * 100 / total).coerceIn(0, 100)
            v.setProgressBar(R.id.w_sets_bar, 100, pct, false)
            v.setTextViewText(
                R.id.w_sets,
                if (rest) s("restLabel", "راحة", "rest") else "$done/$total ${s("labelSets", "مجموعات", "sets")}"
            )

            val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                val pi = PendingIntent.getActivity(
                    ctx, 7001, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                v.setOnClickPendingIntent(R.id.w_root, pi)
            }
            return v
        }
    }
}
