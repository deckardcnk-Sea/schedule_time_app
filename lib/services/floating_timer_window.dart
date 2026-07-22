import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recording_session.dart';

/// 需求4：原生悬浮窗（自写 Kotlin WindowManager 胶囊，取代 system_alert_window 插件）。
///
/// 通过 MethodChannel 与原生 [FloatingWindowService] 通信。原生侧自绘左上角
/// 半透明胶囊（活动名 + 实时计时），点击胶囊通过 PendingIntent 回到 App。
///
/// 显隐策略（见 quick_record_page）：
///   - App 在前台（resumed）→ hide()：应用内不显示胶囊，避免遮挡。
///   - App 离开前台（paused/inactive/detached）且正在计时 → show()：出应用才显示。
///
/// 权限：Android 11+ 需要「显示在其他应用上」，由原生 checkPermission/requestPermission 处理。
class FloatingTimerWindow {
  static const MethodChannel _channel =
      MethodChannel('com.schedule.schedule_time_app/floating_window');

  static bool _visible = false;

  /// 是否已显示悬浮窗
  static bool get isVisible => _visible;

  /// 检查悬浮窗权限（Android 11+ 需要「显示在其他应用上」）
  static Future<bool> ensurePermission() async {
    try {
      final ok = await _channel.invokeMethod<bool>('checkPermission');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳转系统授权页（用户手动开启「显示在其他应用上」）
  static Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod<bool>('requestPermission');
    } catch (_) {
      // 忽略失败
    }
  }

  static String _format(Duration elapsed) {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 显示悬浮窗（首次会拉起原生前台服务）。[colorValue] 为分类颜色（用于胶囊圆点）。
  static Future<void> show(RecordingSession session, int colorValue) async {
    try {
      await _channel.invokeMethod('show', {
        'activity': session.activity,
        'categoryColor': colorValue,
        'timerText': _format(session.elapsed),
      });
      _visible = true;
    } catch (e) {
      debugPrint('悬浮窗 show 失败: $e');
    }
  }

  /// 更新悬浮窗内容（活动名 / 计时 / 颜色）
  static Future<void> update(RecordingSession session, int colorValue) async {
    if (!_visible) return;
    try {
      await _channel.invokeMethod('update', {
        'activity': session.activity,
        'categoryColor': colorValue,
        'timerText': _format(session.elapsed),
      });
    } catch (e) {
      debugPrint('悬浮窗 update 失败: $e');
    }
  }

  /// 隐藏悬浮窗（App 回到前台时调用，不停止服务）
  static Future<void> hide() async {
    if (!_visible) return;
    try {
      await _channel.invokeMethod('hide');
    } catch (e) {
      debugPrint('悬浮窗 hide 失败: $e');
    }
    _visible = false;
  }

  /// 关闭悬浮窗并停止服务（停止计时时调用）
  static Future<void> close() async {
    try {
      await _channel.invokeMethod('close');
    } catch (e) {
      debugPrint('悬浮窗 close 失败: $e');
    }
    _visible = false;
  }
}
