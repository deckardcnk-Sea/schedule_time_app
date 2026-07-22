import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import '../models/recording_session.dart';

/// 需求4：后台计时前台服务封装层。
///
/// 设计原则（复用 RecordingSession 真实时间模型）：
/// - 不把"累计时长"传给服务，而是传 segments + runningStart（墙钟时间）。
/// - 服务侧用与 RecordingSession.elapsed 完全一致的逻辑实时算当前时长，
///   因此 App 退到后台 / 锁屏 / 被系统回收 UI 后，计时依然真实不丢。
/// - 计时通过前台通知（foreground notification）持续展示，满足"后台仍在跑"。
class BackgroundTimerService {
  static const String _channelId = 'schedule_timer';

  /// 初始化前台服务（在 main() 最早调用）。
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
        notificationChannelId: _channelId,
        initialNotificationTitle: '时间记录',
        initialNotificationContent: '未在记录',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// 启动服务并下发当前会话（开始/恢复计时）。
  static Future<void> start(RecordingSession session) async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    _pushSession(service, session);
  }

  /// 计时状态变化（暂停/继续/新增段）时更新服务内会话。
  static Future<void> update(RecordingSession session) async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      _pushSession(service, session);
    }
  }

  /// 停止后台计时并关闭服务。
  static Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
    service.invoke('stopService');
  }

  /// 把会话推给原生服务（转为可序列化的 map）。
  static void _pushSession(
      FlutterBackgroundService service, RecordingSession session) {
    service.invoke('setSession', {
      'session': session.toMap(),
    });
  }

  /// 服务主循环（原生侧隔离运行）。
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance instance) {
    if (instance is AndroidServiceInstance) {
      instance.setAsForegroundService();
    }

    Duration currentElapsed(Map<String, dynamic>? sessionMap) {
      if (sessionMap == null) return Duration.zero;
      final segRaw = (sessionMap['segments'] as List?) ?? [];
      Duration total = Duration.zero;
      for (final e in segRaw) {
        final s = e as Map<String, dynamic>;
        total += DateTime.fromMillisecondsSinceEpoch(s['end'] as int)
            .difference(DateTime.fromMillisecondsSinceEpoch(s['start'] as int));
      }
      final rs = sessionMap['runningStart'];
      if (rs != null) {
        total += DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(rs as int));
      }
      return total;
    }

    String format(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60);
      final hh = h.toString().padLeft(2, '0');
      final mm = m.toString().padLeft(2, '0');
      final ss = s.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }

    Map<String, dynamic>? currentSession;
    String activityName = '';
    Timer? ticker;

    void refreshNotification() {
      final elapsed = currentElapsed(currentSession);
      final text = currentSession == null
          ? '未在记录'
          : '$activityName  ${format(elapsed)}';
      if (instance is AndroidServiceInstance) {
        instance.setForegroundNotificationInfo(
          title: '时间记录',
          content: text,
        );
      }
    }

    instance.on('setSession').listen((event) {
      final payload = event?['session'] as Map<String, dynamic>?;
      currentSession = payload;
      activityName = (payload?['activity'] as String?) ?? '';
      ticker?.cancel();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        refreshNotification();
      });
      refreshNotification();
    });

    instance.on('stop').listen((_) {
      ticker?.cancel();
      currentSession = null;
      refreshNotification();
    });

    // 初始通知
    refreshNotification();
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance instance) async {
    // iOS 不支持与 Android 同等的后台计时，仅保活占位。
    return true;
  }
}
