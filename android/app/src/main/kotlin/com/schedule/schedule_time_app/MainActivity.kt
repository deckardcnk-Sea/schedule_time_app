package com.schedule.schedule_time_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.schedule.schedule_time_app/floating_window"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    // Android 11+ 是否拥有「显示在其他应用上」权限
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "requestPermission" -> {
                    // 跳转到系统授权页（用户手动开启）
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PERM_FAILED", e.message, null)
                    }
                }
                "show" -> {
                    val activity = call.argument<String>("activity") ?: ""
                    val color = call.argument<Int>("categoryColor") ?: -1
                    val timer = call.argument<String>("timerText") ?: "00:00:00"
                    FloatingWindowService.startOrUpdate(this, activity, color, timer)
                    result.success(null)
                }
                "update" -> {
                    val activity = call.argument<String>("activity") ?: ""
                    val color = call.argument<Int>("categoryColor") ?: -1
                    val timer = call.argument<String>("timerText") ?: "00:00:00"
                    FloatingWindowService.update(this, activity, color, timer)
                    result.success(null)
                }
                "hide" -> {
                    FloatingWindowService.hide(this)
                    result.success(null)
                }
                "close" -> {
                    FloatingWindowService.close(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
