package com.qbrahym.vshapeapp

import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val channel = "vshape/native"
    private var notifPermissionCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Alarms.createChannel(this)

        flutterEngine.platformViewsController.registry.let { /* no platform views */ }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {

                "packageInfo" -> {
                    try {
                        val pm = packageManager
                        val info = if (Build.VERSION.SDK_INT >= 33) {
                            pm.getPackageInfo(
                                packageName,
                                android.content.pm.PackageManager.PackageInfoFlags.of(0L)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            pm.getPackageInfo(packageName, 0)
                        }
                        val code: Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode
                        else @Suppress("DEPRECATION") info.versionCode.toLong()
                        result.success(
                            mapOf(
                                "versionName" to (info.versionName ?: "1.0.0"),
                                "versionCode" to code,
                                "packageName" to packageName
                            )
                        )
                    } catch (e: Exception) {
                        result.success(mapOf("versionName" to "1.0.0", "versionCode" to 1L))
                    }
                }

                "canRequestUnknownSources" -> {
                    val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else true
                    result.success(ok)
                }

                "openUnknownSourcesSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val i = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                        } else {
                            val i = Intent(Settings.ACTION_SECURITY_SETTINGS)
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(i)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("settings_failed", e.message, null)
                    }
                }

                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("bad_args", "path is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val f = File(path)
                        if (!f.exists()) {
                            result.error("not_found", "APK file missing: $path", null)
                            return@setMethodCallHandler
                        }
                        val uri: Uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", f
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("install_failed", e.message, null)
                    }
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                            == android.content.pm.PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            notifPermissionCallback = result
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 9001
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }

                "scheduleDaily" -> {
                    val list = call.argument<List<Map<String, Any?>>>("alarms") ?: emptyList()
                    Alarms.save(this, list)
                    val n = Alarms.scheduleAll(this)
                    result.success(n)
                }

                "cancelAll" -> {
                    Alarms.cancelAll(this)
                    result.success(true)
                }

                "scheduled" -> {
                    result.success(Alarms.load(this).map { it.toMap() })
                }

                "deviceAbi" -> {
                    val abis = Build.SUPPORTED_ABIS
                    result.success(if (abis.isNotEmpty()) abis[0] else "")
                }

                "notify" -> {
                    val id = (call.argument<Number>("id"))?.toInt() ?: 9001
                    val title = call.argument<String>("title") ?: "V-System"
                    val body = call.argument<String>("body") ?: ""
                    try {
                        Alarms.notifyNow(this, id, title, body)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "vibrate" -> {
                    val ms = (call.argument<Number>("ms"))?.toLong() ?: 400L
                    Alarms.vibrate(this, ms.coerceIn(0L, 5000L))
                    result.success(true)
                }

                "widgetInstalled" -> {
                    result.success(HomeWidget.isInstalled(this))
                }

                "updateWidget" -> {
                    val json = call.argument<String>("json")
                    try {
                        HomeWidget.updateAll(this, json)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "keepScreenOn" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    runOnUiThread {
                        if (on) {
                            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == 9001) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
            notifPermissionCallback?.success(granted)
            notifPermissionCallback = null
            return
        }
        @Suppress("DEPRECATION")
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
