package com.qbrahym.vshapeapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms all saved reminders and prayer alarms after a reboot or an app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val a = intent.action ?: return
        if (a == Intent.ACTION_BOOT_COMPLETED ||
            a == Intent.ACTION_MY_PACKAGE_REPLACED ||
            a == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            try {
                Alarms.scheduleAll(ctx)
            } catch (e: Exception) {
            }
            try {
                // one-shot prayer alarms: re-arm whatever is still in the future
                Prayers.scheduleAll(ctx)
            } catch (e: Exception) {
            }
            try {
                // redraw the home-screen widget from the cached snapshot
                HomeWidget.updateAll(ctx)
            } catch (e: Exception) {
            }
        }
    }
}
