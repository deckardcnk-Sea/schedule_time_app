package com.schedule.schedule_time_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * 自写原生悬浮窗服务（替代 system_alert_window 2.x 系统条样式）。
 *
 * 用 WindowManager 自绘左上角「胶囊」：
 *   - 半透明深色背景（圆角）+ 白色文字
 *   - 左侧一个小的活动圆点（按 category 颜色）
 *   - 中间活动名，右侧实时计时（HH:MM:SS）
 *   - 整体可点击 → 通过 PendingIntent 回到 App（MainActivity）
 *
 * 该 Service 以前台服务方式运行（dataSync 类型），确保离开 App 后进程被保活、
 * 胶囊持续显示并刷新，直到收到 hide/close 指令。
 *
 * 指令由 MainActivity 中注册的 MethodChannel 转发：
 *   - startOrUpdate：首次 show，之后 update（复用同一窗口）
 *   - hide：移除窗口（停止悬浮，但服务可保留）
 *   - close：移除窗口并停止服务
 */
class FloatingWindowService : Service() {

    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null

    // 胶囊内子控件引用，便于无重建地更新文本
    private var dotView: View? = null
    private var activityTextView: TextView? = null
    private var timerTextView: TextView? = null

    private var categoryColor = Color.WHITE

    companion object {
        private const val CHANNEL_ID = "floating_window_channel"
        private const val NOTIF_ID = 9001

        // 当前是否正在展示胶囊（静态，便于外部判断）
        var isShowing = false
            private set

        // 便捷入口：供 MainActivity 的 MethodChannel handler 调用
        fun startOrUpdate(context: Context, activity: String, categoryColor: Int, timerText: String) {
            val intent = Intent(context, FloatingWindowService::class.java).apply {
                action = "ACTION_START_OR_UPDATE"
                putExtra("activity", activity)
                putExtra("categoryColor", categoryColor)
                putExtra("timerText", timerText)
            }
            // 首次以 startForegroundService 拉起；之后用 startService 复用同一实例
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(context: Context, activity: String, categoryColor: Int, timerText: String) {
            if (!isShowing) return
            val intent = Intent(context, FloatingWindowService::class.java).apply {
                action = "ACTION_UPDATE"
                putExtra("activity", activity)
                putExtra("categoryColor", categoryColor)
                putExtra("timerText", timerText)
            }
            context.startService(intent)
        }

        fun hide(context: Context) {
            val intent = Intent(context, FloatingWindowService::class.java).apply {
                action = "ACTION_HIDE"
            }
            context.startService(intent)
        }

        fun close(context: Context) {
            val intent = Intent(context, FloatingWindowService::class.java).apply {
                action = "ACTION_CLOSE"
            }
            context.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "ACTION_START_OR_UPDATE", "ACTION_UPDATE" -> {
                val activity = intent.getStringExtra("activity") ?: ""
                val color = intent.getIntExtra("categoryColor", Color.WHITE)
                val timer = intent.getStringExtra("timerText") ?: "00:00:00"
                categoryColor = color
                if (isShowing) {
                    updateContent(activity, color, timer)
                } else {
                    startForeground(NOTIF_ID, buildNotification(activity, timer))
                    addFloatingView(activity, color, timer)
                    isShowing = true
                }
            }
            "ACTION_HIDE" -> {
                removeFloatingView()
            }
            "ACTION_CLOSE" -> {
                removeFloatingView()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun buildNotification(activity: String, timer: String): Notification {
        val pi = buildLaunchPendingIntent()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("时间记录")
            .setContentText(if (activity.isEmpty()) "未在记录" else "$activity  $timer")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID,
                "悬浮计时窗",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(chan)
        }
    }

    /** 点击胶囊 → 回到 App（MainActivity）。 */
    private fun buildLaunchPendingIntent(): PendingIntent {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        launch?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun addFloatingView(activity: String, color: Int, timer: String) {
        if (floatingView != null) return

        val wrap = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(6), dp(12), dp(6))
            // 半透明深色胶囊背景
            background = roundedCapsule(Color.parseColor("#CC1C1C1E"))
            isClickable = true
            isFocusable = true
        }

        // 左侧活动圆点
        val dot = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(8)).apply {
                marginEnd = dp(8)
            }
            background = roundedCircle(color)
        }

        // 活动名
        val actTv = TextView(this).apply {
            text = activity
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            ellipsize = android.text.TextUtils.TruncateAt.END
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginEnd = dp(10)
            }
        }

        // 计时
        val timerTv = TextView(this).apply {
            text = timer
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.MONOSPACE
            setPadding(dp(8), 0, 0, 0)
        }

        wrap.addView(dot)
        wrap.addView(actTv)
        wrap.addView(timerTv)

        // 点击回 App
        wrap.setOnClickListener {
            try {
                buildLaunchPendingIntent().send()
            } catch (_: Exception) {
                // 忽略发送失败
            }
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                    or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(12)
            y = dp(40) // 状态栏下方一点
        }

        try {
            windowManager.addView(wrap, params)
            floatingView = wrap
            dotView = dot
            activityTextView = actTv
            timerTextView = timerTv
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateContent(activity: String, color: Int, timer: String) {
        dotView?.background = roundedCircle(color)
        activityTextView?.text = activity
        timerTextView?.text = timer
        // 同步刷新通知栏文本
        if (isShowing) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildNotification(activity, timer))
        }
    }

    private fun removeFloatingView() {
        floatingView?.let {
            try {
                windowManager.removeView(it)
            } catch (_: Exception) {
            }
        }
        floatingView = null
        dotView = null
        activityTextView = null
        timerTextView = null
        isShowing = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        removeFloatingView()
        super.onDestroy()
    }

    // ---- 工具：dp 转 px ----
    private fun dp(value: Int): Int {
        val density = resources.displayMetrics.density
        return (value * density).toInt()
    }

    // 圆角胶囊背景
    private fun roundedCapsule(solidColor: Int): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            cornerRadius = dp(16).toFloat()
            setColor(solidColor)
        }
    }

    private fun roundedCircle(solidColor: Int): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.OVAL
            setColor(solidColor)
        }
    }
}
